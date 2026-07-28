import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../data/drive_session_repository.dart';
import '../domain/drive_session.dart';

/// 기사의 운행 세션 상태.
///
/// 화면이 갈라지는 지점이 세 개라 셋을 구분해서 담는다:
///  - 담당 버스 없음([hasBus] false) — 관리자가 배차를 안 한 기사
///  - 운행 전([active] null) — 방향을 고르고 "운행 시작"을 누르는 화면
///  - 운행 중 — 명단 화면
class DriveSessionState {
  const DriveSessionState({
    required this.hasBus,
    this.busId,
    this.active,
    this.roster = const [],
    this.isSubmitting = false,
    this.actionError,
    this.lastCompleted,
  });

  /// 담당 버스가 아직 없는 기사.
  const DriveSessionState.noBusAssigned() : this(hasBus: false);

  final bool hasBus;
  final int? busId;

  /// 진행 중인 운행. null 이면 운행 전이다.
  final DriveSession? active;

  /// [active] 의 명단. 운행 전에는 비어 있다(세션이 있어야 명단이 나온다).
  final List<RosterEntry> roster;

  /// 운행 시작/종료 전송 중. 버튼만 잠그고 화면은 그대로 둔다 —
  /// 전체를 loading 으로 바꾸면 명단이 사라졌다 나타나 기사가 자리를 잃는다.
  final bool isSubmitting;

  /// 마지막 시작/종료 실패. 사용자에게 [ApiException.message] 를 그대로 보여준다.
  final Object? actionError;

  /// 방금 끝낸 운행. 종료 직후 요약을 보여주는 데 쓴다.
  final DriveSession? lastCompleted;

  bool get isDriving => active != null;

  DriveSessionState copyWith({
    int? busId,
    DriveSession? active,
    bool clearActive = false,
    List<RosterEntry>? roster,
    bool? isSubmitting,
    Object? actionError,
    bool clearError = false,
    DriveSession? lastCompleted,
  }) => DriveSessionState(
    hasBus: hasBus,
    busId: busId ?? this.busId,
    active: clearActive ? null : (active ?? this.active),
    roster: roster ?? this.roster,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    actionError: clearError ? null : (actionError ?? this.actionError),
    lastCompleted: lastCompleted ?? this.lastCompleted,
  );
}

/// 운행 세션의 생애주기(시작 → 진행 → 종료)를 한 곳에서 관리한다.
///
/// 앱을 다시 켜도 운행이 이어져야 하므로, 시작 여부를 로컬에 기억하지 않고
/// **매번 서버에서 진행 중 세션을 찾아온다**. 로컬 플래그로 관리하면 앱을 껐다 켠
/// 기사가 "운행 시작" 화면을 다시 보고 두 번 시작을 눌러 409 를 만난다.
class DriveSessionController extends AsyncNotifier<DriveSessionState> {
  DriveSessionRepository get _repository =>
      ref.read(driveSessionRepositoryProvider);

  @override
  Future<DriveSessionState> build() async {
    // 세션의 busId 가 바뀌면(로그인·재발급) 자동으로 다시 부른다.
    final busId = ref.watch(currentSessionProvider)?.busId;
    if (busId == null) return const DriveSessionState.noBusAssigned();

    final active = await _repository.findActive(busId);
    return DriveSessionState(
      hasBus: true,
      busId: busId,
      active: active,
      roster: active == null ? const [] : await _repository.roster(active.id),
    );
  }

  /// 서버 사실을 다시 읽는다. 당겨서 새로고침·409 복구에 쓴다.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// 운행 시작 → 명단까지 받아온다.
  ///
  /// 명단을 여기서 같이 받는 이유: 학생 이름은 명단에서만 오고, 명단 없이는
  /// 승하차 화면이 아무 의미가 없다. 둘을 한 동작으로 묶어 중간 상태를 없앤다.
  Future<void> start(DriveDirection direction) async {
    final current = state.value;
    final busId = current?.busId;
    if (current == null || busId == null || current.isSubmitting) return;

    state = AsyncValue.data(
      current.copyWith(isSubmitting: true, clearError: true),
    );
    try {
      final session = await _repository.start(
        busId: busId,
        direction: direction,
      );
      final roster = await _repository.roster(session.id);
      state = AsyncValue.data(
        current.copyWith(active: session, roster: roster, isSubmitting: false),
      );
    } on ApiException catch (e) {
      // 409 = 이미 진행 중인 운행이 있다. 버튼을 다시 살리는 게 아니라
      // 서버 사실을 다시 읽어 그 운행으로 들어가는 게 맞는 복구다(계획서 §3.2).
      if (e.kind == ApiErrorKind.conflict) {
        await refresh();
        final after = state.value;
        if (after != null && after.active == null) {
          // 새로고침해도 진행 중 운행이 안 보이는 드문 경우 — 이유를 알려준다.
          state = AsyncValue.data(after.copyWith(actionError: e));
        }
        return;
      }
      state = AsyncValue.data(
        current.copyWith(isSubmitting: false, actionError: e),
      );
    }
  }

  /// 운행 종료.
  ///
  /// 차내 잔류 학생이 있으면 서버가 **409** 로 막는다. 그 실패는 숨기지 않고
  /// [DriveSessionState.actionError] 에 담아 화면이 이유를 그대로 보여주게 한다.
  Future<void> end() async {
    final current = state.value;
    final active = current?.active;
    if (current == null || active == null || current.isSubmitting) return;

    state = AsyncValue.data(
      current.copyWith(isSubmitting: true, clearError: true),
    );
    try {
      final ended = await _repository.end(active.id);
      state = AsyncValue.data(
        current.copyWith(
          clearActive: true,
          roster: const [],
          isSubmitting: false,
          lastCompleted: ended,
        ),
      );
    } on ApiException catch (e) {
      state = AsyncValue.data(
        current.copyWith(isSubmitting: false, actionError: e),
      );
    }
  }

  /// 시작/종료 실패 문구를 지운다. 사용자가 배너를 닫을 때 쓴다.
  void clearActionError() {
    final current = state.value;
    if (current == null || current.actionError == null) return;
    state = AsyncValue.data(current.copyWith(clearError: true));
  }
}

final driveSessionControllerProvider =
    AsyncNotifierProvider<DriveSessionController, DriveSessionState>(
      DriveSessionController.new,
    );

/// 진행 중인 운행만 떼어 본다.
///
/// 이걸 따로 두는 이유: 승하차 화면은 세션이 **바뀔 때만** 승하차 이력을 다시
/// 받아야 한다. [driveSessionControllerProvider] 를 직접 watch 하면 `isSubmitting`
/// 같은 값이 흔들릴 때마다 재조회가 돌아 기록 중이던 상태가 날아간다.
final activeDriveSessionProvider = Provider<DriveSession?>(
  (ref) => ref.watch(driveSessionControllerProvider).value?.active,
);

/// 진행 중인 운행의 명단. [activeDriveSessionProvider] 와 같은 이유로 분리한다.
final driveRosterProvider = Provider<List<RosterEntry>>(
  (ref) => ref.watch(driveSessionControllerProvider).value?.roster ?? const [],
);
