import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
// ⚠️ feature 간 의존이 여기 하나 있다(컨벤션 C-1).
// 승하차 명단은 운행 세션 없이는 존재할 수 없다 — 학생 이름도, 대상 버스도,
// "언제부터의 기록인가"도 전부 세션에서 온다. 원칙대로면 `shared/domain/` 으로
// 올려야 하지만 그건 이 작업(C7) 범위 밖이라, 의존 방향을
// rideevent → drivesession 한쪽으로만 고정해 두고 남긴다.
import '../../drivesession/application/drive_session_controller.dart';
import '../../drivesession/domain/drive_session.dart';
import '../data/ride_event_repository.dart';
import '../domain/ride_event.dart';
import '../domain/roster_student.dart';

/// 승하차 명단 화면 상태.
class DriverRosterState {
  const DriverRosterState({
    required this.students,
    this.direction,
    this.pending = const {},
    this.recordError,
  });

  /// 운행 전 — 보여줄 명단이 없다.
  const DriverRosterState.idle() : this(students: const []);

  final List<RosterStudent> students;

  /// 진행 중인 운행의 방향. 인계(HANDOVER) 단계를 쓸지 정한다.
  final DriveDirection? direction;

  /// 지금 서버로 전송 중인 학생 id. 응답이 오기 전까지 그 줄의 버튼을 잠근다 —
  /// 연타로 같은 기록이 두 번 들어가면 학부모에게 알림도 두 번 간다.
  final Set<int> pending;

  /// 마지막 기록 실패. [ApiException.message] 를 그대로 보여준다.
  final Object? recordError;

  /// 아직 차 안에 있는 학생. **운행 종료를 막는 기준**이다.
  List<RosterStudent> get onboard =>
      students.where((s) => s.isOnboard).toList(growable: false);

  /// 이번 운행에서 처리가 끝난 인원.
  int get doneCount => direction == null
      ? 0
      : students.where((s) => s.nextActionFor(direction!) == null).length;

  bool isPending(int studentId) => pending.contains(studentId);

  DriverRosterState copyWith({
    List<RosterStudent>? students,
    Set<int>? pending,
    Object? recordError,
    bool clearError = false,
  }) => DriverRosterState(
    students: students ?? this.students,
    direction: direction,
    pending: pending ?? this.pending,
    recordError: clearError ? null : (recordError ?? this.recordError),
  );
}

/// 명단 + 그날 승하차 기록을 합쳐 화면에 줄 상태를 만든다.
///
/// 흐름: 운행 세션(이름·대상 버스) → 승하차 이력 조회 → 학생별 현재 단계 계산.
class DriverRosterController extends AsyncNotifier<DriverRosterState> {
  @override
  Future<DriverRosterState> build() async {
    // 세션 컨트롤러 전체가 아니라 "진행 중 운행"과 "명단"만 본다.
    // 전체를 watch 하면 전송 중 플래그가 흔들릴 때마다 이력을 다시 받아
    // 기록 중이던 상태가 날아간다.
    final session = ref.watch(activeDriveSessionProvider);
    final roster = ref.watch(driveRosterProvider);
    if (session == null) return const DriverRosterState.idle();

    final events = await ref
        .read(rideEventRepositoryProvider)
        .busRecords(busId: session.busId, date: session.serviceDate);

    return DriverRosterState(
      students: RosterStudent.merge(
        roster: roster,
        events: events,
        since: session.startedAt,
      ),
      direction: session.direction,
    );
  }

  /// 학생 한 명의 승하차를 기록한다.
  ///
  /// **낙관적 갱신을 하지 않는다.** 전송 중에는 "전송 중"만 보여주고, 상태는
  /// 서버가 실제로 기록한 종류([RideEvent.type])로만 옮긴다. 미리 "승차 완료"로
  /// 바꿔놓으면 전송이 실패했을 때 기사가 잘못 안심한 채 다음 정류장으로 간다.
  Future<void> record(int studentId, RideEventType type) async {
    final before = state.value;
    final session = ref.read(activeDriveSessionProvider);
    if (before == null || session == null) return;
    if (before.isPending(studentId)) return;

    state = AsyncValue.data(
      before.copyWith(
        pending: {...before.pending, studentId},
        clearError: true,
      ),
    );

    try {
      final event = await ref
          .read(rideEventRepositoryProvider)
          .record(busId: session.busId, studentId: studentId, type: type);
      _finish(studentId, applied: event);
    } on ApiException catch (e) {
      _finish(studentId, error: e);
    } on FormatException catch (e) {
      _finish(studentId, error: e);
    }
  }

  /// 기록 실패 문구를 지운다. 사용자가 배너를 닫을 때 쓴다.
  void clearRecordError() {
    final current = state.value;
    if (current == null || current.recordError == null) return;
    state = AsyncValue.data(current.copyWith(clearError: true));
  }

  /// 전송이 끝난 학생을 잠금 해제하고 결과를 반영한다.
  ///
  /// 여러 학생을 동시에 기록할 수 있으므로 `before` 가 아니라 **지금 상태**를
  /// 다시 읽어 갱신한다. 안 그러면 나중에 끝난 응답이 먼저 끝난 결과를 덮는다.
  void _finish(int studentId, {RideEvent? applied, Object? error}) {
    final current = state.value;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(
        students: applied == null
            ? current.students
            : [
                for (final student in current.students)
                  student.studentId == studentId
                      ? student.withEvent(applied)
                      : student,
              ],
        pending: current.pending.difference({studentId}),
        recordError: error,
        clearError: error == null,
      ),
    );
  }
}

final driverRosterControllerProvider =
    AsyncNotifierProvider<DriverRosterController, DriverRosterState>(
      DriverRosterController.new,
    );
