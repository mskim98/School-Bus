import '../../../core/map/spec/map_view_adapter.dart';
import '../../drivesession/domain/drive_session.dart';
import 'ride_event.dart';

/// 학생 한 명의 현재 처리 단계.
///
/// 서버는 **순서를 강제하지 않는다** — 승차 없이 하차를 보내도 200 이 온다
/// (2026-07-28 실제 API 확인). 그래서 "지금 누를 수 있는 동작"을 정하는 책임이
/// 클라이언트에 있다. 잘못 누르면 학부모에게 틀린 알림이 나가고 되돌릴 수 없다.
enum RideStatus {
  waiting('대기'),
  boarded('승차 완료'),
  alighted('하차 완료'),
  handedOver('보호자 인계 완료');

  const RideStatus(this.label);

  final String label;

  static RideStatus of(RideEventType? lastEvent) => switch (lastEvent) {
    null => RideStatus.waiting,
    RideEventType.board => RideStatus.boarded,
    RideEventType.alight => RideStatus.alighted,
    RideEventType.handover => RideStatus.handedOver,
  };
}

/// 명단 화면의 한 줄 — **운행 명단 + 승하차 기록을 합친 결과**다.
///
/// 이름·정류장은 `GET /api/drive-sessions/{id}/roster`, 현재 단계는
/// `GET /api/ride-events/bus/{busId}` 에서 온다. 두 응답을 합쳐야 완성되므로
/// DTO 가 아니라 domain 모델이다(컨벤션 §4).
class RosterStudent {
  const RosterStudent({
    required this.studentId,
    required this.name,
    required this.status,
    this.location,
    this.point,
    this.updatedAt,
  });

  final int studentId;
  final String name;

  /// 등원이면 승차 정류장, 하원이면 하차지.
  final String? location;

  /// [location] 의 좌표. 명단을 정차 단위로 묶는 키다(`RosterStopGroup`).
  final GeoPoint? point;

  final RideStatus status;

  /// 마지막 기록 시각. 기사가 "방금 눌렀나?"를 눈으로 확인하는 근거다.
  final DateTime? updatedAt;

  /// 아직 차 안에 있는가. **운행 종료를 막는 기준**이다.
  bool get isOnboard => status == RideStatus.boarded;

  /// 다음에 눌러야 할 동작 하나. null 이면 이 학생은 처리가 끝났다.
  ///
  /// 버튼을 하나만 노출해 **학생 1명 처리에 탭 1회**로 끝내고, 동시에 순서가
  /// 어긋난 기록(승차 없이 하차 등)이 애초에 만들어지지 않게 한다.
  /// 등원(`PICKUP`)에는 인계 단계가 없다 — 학원에 내려주면 끝이다.
  RideEventType? nextActionFor(DriveDirection direction) => switch (status) {
    RideStatus.waiting => RideEventType.board,
    RideStatus.boarded => RideEventType.alight,
    RideStatus.alighted =>
      direction == DriveDirection.dropoff ? RideEventType.handover : null,
    RideStatus.handedOver => null,
  };

  RosterStudent withEvent(RideEvent event) => RosterStudent(
    studentId: studentId,
    name: name,
    location: location,
    point: point,
    status: RideStatus.of(event.type),
    updatedAt: event.occurredAt,
  );

  /// 명단과 그날 승하차 기록을 합친다.
  ///
  /// ⚠️ [since] 는 **이번 운행이 시작된 시각**이다. `GET /api/ride-events/bus/{busId}`
  /// 는 날짜 단위로 **그날 전부**를 주기 때문에, 아침 등원에서 남은 기록이 오후 하원
  /// 명단에 그대로 묻어 온다(등원 마지막이 `ALIGHT` 라 하원 시작부터 "하차 완료"로
  /// 보인다). 세션 시작 이후 기록만 세어야 단계가 맞는다.
  static List<RosterStudent> merge({
    required List<RosterEntry> roster,
    required List<RideEvent> events,
    required DateTime since,
  }) {
    final latest = <int, RideEvent>{};
    for (final event in events) {
      if (event.occurredAt.isBefore(since)) continue;
      final previous = latest[event.studentId];
      // 응답 순서를 믿지 않고 가장 늦은 기록을 직접 고른다.
      if (previous == null || !event.occurredAt.isBefore(previous.occurredAt)) {
        latest[event.studentId] = event;
      }
    }

    return [
      for (final entry in roster)
        RosterStudent(
          studentId: entry.studentId,
          name: entry.name,
          location: entry.location,
          point: entry.point,
          status: RideStatus.of(latest[entry.studentId]?.type),
          updatedAt: latest[entry.studentId]?.occurredAt,
        ),
    ];
  }
}
