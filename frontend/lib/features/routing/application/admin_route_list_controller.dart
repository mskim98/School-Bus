import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/routing_repository.dart';
import '../domain/route_plan.dart';
import 'admin_tenant_provider.dart';

/// 노선 목록의 버스 필터. null 이면 학원 전체.
class AdminRouteBusFilter extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? busId) => state = busId;
}

final adminRouteBusFilterProvider = NotifierProvider<AdminRouteBusFilter, int?>(
  AdminRouteBusFilter.new,
);

class AdminRoutePlansState {
  const AdminRoutePlansState({this.plans = const [], this.busIds = const []});

  final List<RoutePlan> plans;

  /// 필터 후보로 보여줄 버스 id 목록.
  final List<int> busIds;

  bool get isEmpty => plans.isEmpty;
}

/// 관리자: 노선 계획 목록(C11).
///
/// 필터를 서버로 보내는 이유 — 학원 계획은 배차를 돌릴 때마다 version 이 올라간 새 행으로
/// 쌓이므로, 버스가 늘면 클라이언트에서 거르는 방식은 곧 한계에 부딪힌다.
class AdminRoutePlansController extends AsyncNotifier<AdminRoutePlansState> {
  /// 필터 없이 조회했을 때 본 버스 목록.
  ///
  /// 필터를 걸면 응답에 그 버스 계획만 남아 후보가 사라진다 —
  /// 그럼 다른 버스로 옮겨갈 방법이 없어지므로 마지막 전체 조회 결과를 기억해 둔다.
  List<int> _knownBusIds = const [];

  @override
  Future<AdminRoutePlansState> build() async {
    final tenant = ref.watch(adminTenantProvider);
    if (tenant == null) return const AdminRoutePlansState();

    final busId = ref.watch(adminRouteBusFilterProvider);
    final plans = await ref
        .read(routingRepositoryProvider)
        .getPlans(tenantId: tenant.id, busId: busId);

    if (busId == null) {
      _knownBusIds = plans.map((plan) => plan.busId).toSet().toList()..sort();
    }
    return AdminRoutePlansState(plans: plans, busIds: _knownBusIds);
  }

  /// 확정 직후·수동 새로고침. 목록이 곧바로 최신 상태를 반영해야 한다.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final adminRoutePlansProvider =
    AsyncNotifierProvider<AdminRoutePlansController, AdminRoutePlansState>(
      AdminRoutePlansController.new,
    );

/// 노선 상세(C11).
///
/// 목록 응답에도 `stops`·`polyline` 이 들어 있지만 상세는 `GET /api/route-plans/{id}` 로
/// 다시 읽는다 — 목록을 띄워둔 채 오래 열려 있던 화면이 낡은 정차 순서를 보여주는 걸 막는다.
final adminRoutePlanDetailProvider = FutureProvider.family<RoutePlan, int>(
  (ref, planId) => ref.read(routingRepositoryProvider).getPlan(planId),
);
