import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/routing/application/admin_route_list_controller.dart';
import 'package:school_bus/features/routing/application/admin_tenant_provider.dart';
import 'package:school_bus/features/routing/data/routing_repository.dart';
import 'package:school_bus/features/routing/domain/auto_assign_result.dart';
import 'package:school_bus/features/routing/domain/route_plan.dart';
import 'package:school_bus/features/routing/domain/route_plan_status.dart';

class FakeRoutingRepository implements RoutingRepository {
  FakeRoutingRepository(this.plans);

  final List<RoutePlan> plans;

  /// 서버로 나간 요청 기록 — 필터가 실제로 서버까지 갔는지 본다.
  final List<({int tenantId, int? busId})> listCalls = [];

  @override
  Future<List<RoutePlan>> getPlans({required int tenantId, int? busId}) async {
    listCalls.add((tenantId: tenantId, busId: busId));
    if (busId == null) return plans;
    return plans.where((plan) => plan.busId == busId).toList();
  }

  @override
  Future<RoutePlan> getPlan(int planId) async =>
      plans.firstWhere((plan) => plan.id == planId);

  @override
  Future<AutoAssignResult> autoAssign({
    required int tenantId,
    required RouteDirection direction,
    DateTime? serviceDate,
  }) async => const AutoAssignResult(plans: [], excludedStudentNames: []);

  @override
  Future<List<RoutePlan>> confirmAutoAssign({
    required List<int> planIds,
  }) async => const [];

  @override
  Future<List<RoutePlan>> getDriverPlans({
    required int busId,
    DateTime? serviceDate,
  }) async => const [];
}

RoutePlan planOf({required int id, required int busId}) => RoutePlan(
  id: id,
  busId: busId,
  direction: RouteDirection.dropoff,
  serviceDate: DateTime(2026, 7, 28),
  totalDistanceM: 4618,
  totalDuration: const Duration(seconds: 1368),
  path: const [],
  stops: const [],
  status: RoutePlanStatus.published,
);

ProviderContainer containerWith(FakeRoutingRepository repository) {
  final container = ProviderContainer(
    overrides: [
      routingRepositoryProvider.overrideWithValue(repository),
      adminTenantProvider.overrideWithValue(
        const AdminTenant(id: 1, isFixedFallback: false),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('학원 전체 계획을 불러오고 버스 후보를 추린다', () async {
    final repository = FakeRoutingRepository([
      planOf(id: 3, busId: 1),
      planOf(id: 2, busId: 2),
      planOf(id: 1, busId: 1),
    ]);
    final container = containerWith(repository);

    final state = await container.read(adminRoutePlansProvider.future);

    expect(state.plans, hasLength(3));
    expect(state.busIds, [1, 2]);
    expect(repository.listCalls.single, (tenantId: 1, busId: null));
  });

  test('★ 버스 필터는 서버로 나가고, 필터를 걸어도 후보 목록은 남는다', () async {
    final repository = FakeRoutingRepository([
      planOf(id: 3, busId: 1),
      planOf(id: 2, busId: 2),
    ]);
    final container = containerWith(repository);
    await container.read(adminRoutePlansProvider.future);

    container.read(adminRouteBusFilterProvider.notifier).select(2);
    final state = await container.read(adminRoutePlansProvider.future);

    expect(state.plans.single.busId, 2);
    expect(repository.listCalls.last, (tenantId: 1, busId: 2));
    // 후보가 {2} 로 줄면 1호차로 돌아갈 방법이 사라진다.
    expect(state.busIds, [1, 2], reason: '전체 조회 때 본 버스를 기억해 둔다');
  });

  test('계획이 없으면 빈 상태 — 에러가 아니다', () async {
    final container = containerWith(FakeRoutingRepository(const []));

    final state = await container.read(adminRoutePlansProvider.future);

    expect(state.isEmpty, isTrue);
  });

  test('관리자 세션이 없으면 조회하지 않는다', () async {
    final repository = FakeRoutingRepository([planOf(id: 1, busId: 1)]);
    final container = ProviderContainer(
      overrides: [
        routingRepositoryProvider.overrideWithValue(repository),
        adminTenantProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(adminRoutePlansProvider.future);

    expect(state.isEmpty, isTrue);
    expect(repository.listCalls, isEmpty);
  });

  test('상세는 목록이 아니라 상세 엔드포인트에서 다시 읽는다', () async {
    final repository = FakeRoutingRepository([
      planOf(id: 3, busId: 1),
      planOf(id: 2, busId: 2),
    ]);
    final container = containerWith(repository);

    final plan = await container.read(adminRoutePlanDetailProvider(2).future);

    expect(plan.id, 2);
    expect(plan.busId, 2);
  });
}
