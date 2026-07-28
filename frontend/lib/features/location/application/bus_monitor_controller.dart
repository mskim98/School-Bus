import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../data/dto/bus_summary_dto.dart';
import '../data/location_repository.dart';
import '../domain/monitored_bus.dart';

/// `PLATFORM_ADMIN` 이 볼 학원 id — **시드 기준 고정값**이다(계획서 §8 D3).
///
/// 플랫폼 관리자는 소속 학원이 없어 JWT 에 `tenantId` 가 없는데, 위치·버스 조회는
/// `tenantId` 가 **필수**라 생략하면 400 이다(실측 확인). 학원 목록 API 는 MVP 17개
/// 밖이라 드롭다운을 만들 수 없어, MVP 에서는 1번 학원으로 고정하고 화면에 그렇다고
/// 표시한다. 학원 선택 UI 가 생기면 이 상수는 사라진다.
const int platformAdminFallbackTenantId = 1;

class BusMonitorState {
  const BusMonitorState({
    required this.tenantId,
    required this.isTenantFallback,
    required this.buses,
    required this.roster,
    this.updatedAt,
    this.pollErrorMessage,
    this.selectedBusId,
    this.pausedByLifecycle = false,
  });

  final int tenantId;

  /// 세션에 소속 학원이 없어 [platformAdminFallbackTenantId] 를 쓴 경우.
  /// 화면이 "고정값"임을 표시해 다른 학원을 보고 있다고 오해하지 않게 한다.
  final bool isTenantFallback;

  final List<MonitoredBus> buses;

  /// 버스 명단(`GET /api/buses` 결과). 폴링은 **위치만** 다시 부르므로,
  /// 위치가 없는 버스를 목록에 계속 세우려면 명단을 들고 있어야 한다.
  final List<BusSummaryDto> roster;

  /// 마지막으로 폴링에 **성공**한 시각.
  final DateTime? updatedAt;

  /// 폴링 실패 사유. 값이 있어도 [buses] 의 마지막 좌표는 그대로 둔다 —
  /// 한 번 실패했다고 지도를 비우면 깜빡이기만 하고 정보는 줄어든다.
  final String? pollErrorMessage;

  final int? selectedBusId;

  final bool pausedByLifecycle;

  int get positionedCount => buses.where((b) => b.hasPosition).length;

  MonitoredBus? get selectedBus {
    for (final bus in buses) {
      if (bus.busId == selectedBusId) return bus;
    }
    return null;
  }

  BusMonitorState copyWith({
    List<MonitoredBus>? buses,
    DateTime? updatedAt,
    String? pollErrorMessage,
    int? selectedBusId,
    bool? pausedByLifecycle,
    bool clearError = false,
    bool clearSelection = false,
  }) => BusMonitorState(
    tenantId: tenantId,
    isTenantFallback: isTenantFallback,
    buses: buses ?? this.buses,
    roster: roster,
    updatedAt: updatedAt ?? this.updatedAt,
    pollErrorMessage: clearError
        ? null
        : (pollErrorMessage ?? this.pollErrorMessage),
    selectedBusId: clearSelection
        ? null
        : (selectedBusId ?? this.selectedBusId),
    pausedByLifecycle: pausedByLifecycle ?? this.pausedByLifecycle,
  );
}

/// 관리자 관제 지도(C9).
///
/// ⚠️ **버스 위치는 WebSocket 으로 오지 않는다**(계획서 §3.6). STOMP 구독 목록의
/// `location` 채널은 전부 *학생* 위치라, 버스는 [pollInterval] 마다 직접 다시 부른다.
/// 서버 위치 갱신 주기가 3초여서 더 자주 불러도 새 값이 없다.
class BusMonitorController extends AsyncNotifier<BusMonitorState> {
  static const pollInterval = Duration(seconds: 3);

  Timer? _timer;

  @override
  Future<BusMonitorState> build() async {
    // 화면을 벗어나 provider 가 정리될 때 폴링이 살아남지 않게 한다.
    ref.onDispose(_cancelTimer);

    final session = ref.watch(currentSessionProvider);
    final tenantId = session?.tenantId ?? platformAdminFallbackTenantId;

    final repository = ref.read(locationRepositoryProvider);
    // 순차 호출이다. 병렬(record.wait)로 묶으면 실패가 ParallelWaitError 로 감싸져
    // ApiException 의 message 를 잃는다 — 사용자에게 보여줄 문구가 사라진다.
    final roster = await repository.getBuses(tenantId: tenantId);
    final locations = await repository.getBusLocations(tenantId: tenantId);

    final now = DateTime.now();
    _startTimer();

    return BusMonitorState(
      tenantId: tenantId,
      isTenantFallback: session?.tenantId == null,
      roster: roster,
      buses: MonitoredBus.merge(
        buses: roster,
        locations: locations,
        observedAt: now,
      ),
      updatedAt: now,
    );
  }

  /// 전체 재조회(버스 명단 포함). 에러 화면의 "다시 시도"가 부른다.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  void select(int? busId) {
    final current = state.value;
    if (current == null) return;
    // 같은 버스를 다시 누르면 선택 해제 — 지도 전체를 다시 보고 싶을 때 쓴다.
    final isSame = current.selectedBusId == busId;
    state = AsyncValue.data(
      isSame
          ? current.copyWith(clearSelection: true)
          : current.copyWith(
              selectedBusId: busId,
              clearSelection: busId == null,
            ),
    );
  }

  void pause() {
    final current = state.value;
    if (current == null || current.pausedByLifecycle) return;
    _cancelTimer();
    state = AsyncValue.data(current.copyWith(pausedByLifecycle: true));
  }

  void resume() {
    final current = state.value;
    if (current == null || !current.pausedByLifecycle) return;
    state = AsyncValue.data(current.copyWith(pausedByLifecycle: false));
    _startTimer();
  }

  void _startTimer() {
    _cancelTimer();
    _timer = Timer.periodic(pollInterval, (_) => _poll());
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 위치만 다시 부른다. 버스 명단은 운행 중에 바뀌지 않아 초기 1회면 충분하다.
  Future<void> _poll() async {
    final current = state.value;
    if (current == null) return;

    try {
      final locations = await ref
          .read(locationRepositoryProvider)
          .getBusLocations(tenantId: current.tenantId);

      // await 사이에 화면을 벗어났을 수 있다.
      if (!ref.mounted) return;
      final now = DateTime.now();
      state = AsyncValue.data(
        current.copyWith(
          buses: MonitoredBus.merge(
            buses: current.roster,
            locations: locations,
            observedAt: now,
            previous: current.buses,
          ),
          updatedAt: now,
          clearError: true,
        ),
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      // 마지막 좌표는 그대로 두고 실패만 알린다(컨벤션 §7-1: 분기는 status 로만).
      state = AsyncValue.data(current.copyWith(pollErrorMessage: e.message));
    }
  }
}

final busMonitorControllerProvider =
    AsyncNotifierProvider<BusMonitorController, BusMonitorState>(
      BusMonitorController.new,
    );
