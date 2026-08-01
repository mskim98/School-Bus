import '../../drivesession/domain/drive_session.dart';
import '../../rideevent/domain/ride_event.dart';

/// 버스 한 대가 지금 어느 단계에 있는가.
///
/// **`운행 전` 과 `운행 종료` 를 합치지 않는다.** 둘 다 "지금 안 달린다"지만
/// 관리자가 할 행동이 정반대다 — 운행 전은 기사에게 시작을 재촉할 일이고,
/// 운행 종료는 이미 끝난 건이라 손댈 게 없다. 하나로 묶으면 오늘 아직 출발도
/// 안 한 버스를 "끝났다"고 읽는다.
enum BusOperationPhase {
  /// 오늘 시작한 운행이 없다.
  notStarted('운행 전', '·'),

  /// `IN_PROGRESS` 세션이 있다.
  inProgress('운행 중', '▶'),

  /// 오늘 시작한 운행이 끝났다.
  completed('운행 종료', '✓');

  const BusOperationPhase(this.label, this.icon);

  /// 화면에 그대로 쓰는 한글 이름.
  final String label;

  /// 상태 칩에 붙는 문자 아이콘. 색만으로 구분하지 않기 위한 것이다(§0-1).
  final String icon;
}

/// 관제 화면이 보는 **버스 한 대의 운행 상태**.
///
/// 응답 세 개(운행 세션·승하차 기록·버스 명부)를 합쳐야 완성되므로 DTO 가 아니다
/// (컨벤션 §4). 합치는 계산만 여기 두고, 조회·조립은 화면이 한다(C-1 예외).
///
/// ⚠️ **`예정 인원` 과 `현재 탑승` 은 전혀 다른 값이다.** 서버 버스 응답의 필드명이
/// `onboard` 라 탑승 인원처럼 보이지만 실제로는 **배정 명부의 크기**다
/// (`BusDto.assignedCount` 주석). 지금 차에 탄 사람 수는 승하차 기록을 접어야만
/// 나온다. 둘을 같은 줄에 나란히 두면 관리자가 "20명 중 20명 탑승"으로 읽는다.
class BusOperationStatus {
  const BusOperationStatus({
    required this.phase,
    this.session,
    this.assignedCount,
    this.onboardStudentIds = const [],
    this.processedCount,
    this.elapsed,
    this.countsKnown = false,
  });

  final BusOperationPhase phase;

  /// 이 상태의 근거가 된 세션. [BusOperationPhase.notStarted] 면 null 일 수 있다.
  final DriveSession? session;

  /// **예정 인원** — 이 버스에 배정된 학생 수. 모르면 null(0 으로 채우지 않는다).
  final int? assignedCount;

  /// **현재 탑승 중인 학생** — 세션 시작 이후 마지막 기록이 `BOARD` 인 학생들.
  /// [countsKnown] 이 false 면 항상 비어 있다(계산하지 않았다는 뜻).
  final List<int> onboardStudentIds;

  /// 세션 구간에 기록이 한 번이라도 있는 학생 수. 모르면 null.
  final int? processedCount;

  /// 운행 경과 시간. 운행 전이면 null.
  final Duration? elapsed;

  /// 승하차 기록을 실제로 받아 셌는가.
  ///
  /// false 면 [onboardCount] 를 **0 이 아니라 `—`** 로 그려야 한다. 0 으로 그리면
  /// "아무도 안 탔다"는 확정 정보가 되는데, 실제로는 아직 모르는 상태다.
  final bool countsKnown;

  /// 지금 차에 타고 있는 인원. 모르면 null.
  int? get onboardCount => countsKnown ? onboardStudentIds.length : null;

  /// 운행 방향(등원/하원). 세션이 없으면 null.
  DriveDirection? get direction => session?.direction;

  /// 세션·기록·배정 인원을 합친다.
  ///
  /// [events] 가 null 이면 "아직 안 받았다"는 뜻이고, 빈 목록이면 "받았는데 없다"는
  /// 뜻이다. 둘을 같게 다루면 조회 전 화면이 `0명 탑승` 을 확정 표시한다.
  ///
  /// [now] 는 경과 시간 기준이다.
  static BusOperationStatus of({
    required DriveSession? session,
    required List<RideEvent>? events,
    required int? assignedCount,
    required DateTime now,
  }) {
    if (session == null) {
      return BusOperationStatus(
        phase: BusOperationPhase.notStarted,
        assignedCount: assignedCount,
      );
    }

    // 어제 끝난 운행이 남아 있어도 오늘은 **아직 시작 전**이다.
    final isToday = _isSameDay(session.serviceDate, now);
    if (!session.isInProgress && !isToday) {
      return BusOperationStatus(
        phase: BusOperationPhase.notStarted,
        assignedCount: assignedCount,
      );
    }

    final phase = session.isInProgress
        ? BusOperationPhase.inProgress
        : BusOperationPhase.completed;

    if (events == null) {
      return BusOperationStatus(
        phase: phase,
        session: session,
        assignedCount: assignedCount,
        elapsed: _elapsedOf(session, now),
      );
    }

    final latest = _latestPerStudent(session, events);
    return BusOperationStatus(
      phase: phase,
      session: session,
      assignedCount: assignedCount,
      countsKnown: true,
      processedCount: latest.length,
      onboardStudentIds: [
        for (final entry in latest.entries)
          if (entry.value.type == RideEventType.board) entry.key,
      ],
      elapsed: _elapsedOf(session, now),
    );
  }

  /// 학생별 **세션 구간 안의 마지막 기록**.
  ///
  /// ⚠️ 세션 구간으로 자르는 게 핵심이다. `GET /api/ride-events` 는 날짜 단위라
  /// 아침 등원 기록이 오후 하원 조회에 그대로 묻어 온다 — 등원 마지막이 `ALIGHT`
  /// 라서, 안 자르면 하원 시작 직후에도 "탑승 0명"으로 보인다
  /// (`RosterStudent.merge` 가 겪은 함정과 같다).
  ///
  /// 끝은 양 끝을 포함한다. 마지막 하차 기록 직후 종료를 누르는 게 정상 흐름이라
  /// 종료 시각과 같은 초의 기록을 빼면 그 한 건이 사라진다.
  static Map<int, RideEvent> _latestPerStudent(
    DriveSession session,
    List<RideEvent> events,
  ) {
    final endedAt = session.endedAt;
    final latest = <int, RideEvent>{};

    for (final event in events) {
      if (event.occurredAt.isBefore(session.startedAt)) continue;
      if (endedAt != null && event.occurredAt.isAfter(endedAt)) continue;

      final previous = latest[event.studentId];
      // 응답 순서를 믿지 않고 가장 늦은 기록을 직접 고른다.
      if (previous == null || !event.occurredAt.isBefore(previous.occurredAt)) {
        latest[event.studentId] = event;
      }
    }
    return latest;
  }

  /// 진행 중이면 지금까지, 끝났으면 실제 소요 시간.
  ///
  /// ⚠️ 진행 중 값은 **서버 시각과 기기 시각을 뺀 것**이라 두 시계가 어긋나면
  /// 같이 어긋난다(`startedAt` 에 오프셋이 없다 — `DriveSessionDto` 주석). 음수가
  /// 나오면 계산을 포기하고 null 을 준다. 틀린 경과 시간을 보여주느니 시작 시각만
  /// 보여주는 편이 낫다.
  static Duration? _elapsedOf(DriveSession session, DateTime now) {
    if (!session.isInProgress) return session.elapsed;
    final elapsed = now.difference(session.startedAt);
    return elapsed.isNegative ? null : elapsed;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
