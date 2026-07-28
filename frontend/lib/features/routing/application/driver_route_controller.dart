import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/routing_repository.dart';
import '../domain/route_plan.dart';

/// 기사의 오늘 노선.
///
/// 배포된 노선이 없으면 **빈 목록**이다(에러 아님) — 관리자가 아직 배차를 확정하지
/// 않았을 뿐이라 화면은 빈 상태 안내를 보여준다.
///
/// 담당 버스가 없는(배차 전) 기사는 [DriverRouteState.noBusAssigned] 로 구분한다.
/// "노선이 없다"와 "버스 자체가 없다"는 사용자가 해야 할 행동이 다르다.
class DriverRouteController extends AsyncNotifier<DriverRouteState> {
  @override
  Future<DriverRouteState> build() async {
    // 세션의 busId 가 바뀌면(로그인·재발급) 자동으로 다시 부른다.
    final busId = ref.watch(currentSessionProvider)?.busId;
    if (busId == null) return const DriverRouteState.noBusAssigned();

    final plans = await ref
        .read(routingRepositoryProvider)
        .getDriverPlans(busId: busId);
    return DriverRouteState(plans: plans);
  }

  /// 당겨서 새로고침. `ROUTE_PUBLISHED` 알림을 받았을 때도 이걸 부른다(C13).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }

  /// 등원/하원 탭 전환.
  void select(RouteDirection direction) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(selected: direction));
  }
}

class DriverRouteState {
  const DriverRouteState({
    this.plans = const [],
    this.selected,
    this.hasBus = true,
  });

  /// 아직 버스가 배차되지 않은 기사.
  ///
  /// "노선이 없다"와 구분하는 이유 — 사용자가 해야 할 행동이 다르다.
  /// 전자는 기다리면 되고, 후자는 관리자에게 배차를 요청해야 한다.
  const DriverRouteState.noBusAssigned() : this(hasBus: false);

  final List<RoutePlan> plans;

  /// 사용자가 고른 방향. null 이면 첫 번째 노선을 보여준다.
  final RouteDirection? selected;

  final bool hasBus;

  bool get isEmpty => plans.isEmpty;

  /// 지금 보여줄 노선. 고른 게 없으면 첫 번째.
  RoutePlan? get current {
    if (plans.isEmpty) return null;
    if (selected == null) return plans.first;
    for (final plan in plans) {
      if (plan.direction == selected) return plan;
    }
    return plans.first;
  }

  /// 방향 탭을 보여줄지 — 등원·하원이 둘 다 있을 때만 의미가 있다.
  List<RouteDirection> get availableDirections =>
      plans.map((p) => p.direction).toSet().toList(growable: false);

  DriverRouteState copyWith({RouteDirection? selected}) => DriverRouteState(
    plans: plans,
    selected: selected ?? this.selected,
    hasBus: hasBus,
  );
}

final driverRouteControllerProvider =
    AsyncNotifierProvider<DriverRouteController, DriverRouteState>(
      DriverRouteController.new,
    );
