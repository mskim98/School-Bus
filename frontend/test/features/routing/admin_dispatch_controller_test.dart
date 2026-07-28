import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/api/api_exception.dart';
import 'package:school_bus/features/routing/application/admin_dispatch_controller.dart';
import 'package:school_bus/features/routing/application/admin_tenant_provider.dart';
import 'package:school_bus/features/routing/data/routing_repository.dart';
import 'package:school_bus/features/routing/domain/auto_assign_result.dart';
import 'package:school_bus/features/routing/domain/route_plan.dart';
import 'package:school_bus/features/routing/domain/route_plan_status.dart';

/// dio 를 태우지 않고 repository 만 갈아끼운다 — 컨트롤러의 상태 전이만 본다.
class FakeRoutingRepository implements RoutingRepository {
  FakeRoutingRepository({this.proposal, this.confirmError});

  final AutoAssignResult? proposal;

  /// 확정 시 던질 예외. null 이면 성공한다.
  final Object? confirmError;

  int autoAssignCalls = 0;
  List<int>? confirmedPlanIds;

  @override
  Future<AutoAssignResult> autoAssign({
    required int tenantId,
    required RouteDirection direction,
    DateTime? serviceDate,
  }) async {
    autoAssignCalls++;
    return proposal ??
        const AutoAssignResult(plans: [], excludedStudentNames: []);
  }

  @override
  Future<List<RoutePlan>> confirmAutoAssign({
    required List<int> planIds,
  }) async {
    confirmedPlanIds = planIds;
    if (confirmError != null) throw confirmError!;
    return planIds
        .map((id) => planOf(id: id, status: RoutePlanStatus.published))
        .toList();
  }

  @override
  Future<List<RoutePlan>> getPlans({required int tenantId, int? busId}) async =>
      const [];

  @override
  Future<RoutePlan> getPlan(int planId) async => planOf(id: planId);

  @override
  Future<List<RoutePlan>> getDriverPlans({
    required int busId,
    DateTime? serviceDate,
  }) async => const [];
}

RoutePlan planOf({
  required int id,
  RoutePlanStatus status = RoutePlanStatus.recommended,
}) => RoutePlan(
  id: id,
  busId: 1,
  direction: RouteDirection.pickup,
  serviceDate: DateTime(2026, 7, 28),
  totalDistanceM: 4618,
  totalDuration: const Duration(seconds: 1368),
  path: const [],
  stops: const [],
  status: status,
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
  test('처음에는 제안 전 단계다', () async {
    final container = containerWith(FakeRoutingRepository());

    final state = await container.read(adminDispatchControllerProvider.future);

    expect(state.stage, DispatchStage.idle);
    expect(state.canConfirm, isFalse, reason: '제안이 없으면 확정할 것도 없다');
  });

  test('제안을 받으면 검토 단계로 넘어간다 — 아직 확정은 아니다', () async {
    final repository = FakeRoutingRepository(
      proposal: AutoAssignResult(
        plans: [planOf(id: 2)],
        excludedStudentNames: const ['최지우'],
      ),
    );
    final container = containerWith(repository);
    await container.read(adminDispatchControllerProvider.future);

    await container.read(adminDispatchControllerProvider.notifier).propose();
    final state = container.read(adminDispatchControllerProvider).value!;

    expect(repository.autoAssignCalls, 1);
    expect(state.stage, DispatchStage.review);
    expect(state.proposal?.excludedStudentNames, ['최지우']);
    expect(state.canConfirm, isTrue);
  });

  test('확정하면 배포된 계획이 담긴 확정 단계가 된다', () async {
    final repository = FakeRoutingRepository(
      proposal: AutoAssignResult(
        plans: [planOf(id: 2), planOf(id: 3)],
        excludedStudentNames: const [],
      ),
    );
    final container = containerWith(repository);
    await container.read(adminDispatchControllerProvider.future);
    await container.read(adminDispatchControllerProvider.notifier).propose();

    await container.read(adminDispatchControllerProvider.notifier).confirm();
    final state = container.read(adminDispatchControllerProvider).value!;

    expect(repository.confirmedPlanIds, [2, 3]);
    expect(state.stage, DispatchStage.confirmed);
    expect(state.confirmed.every((p) => p.status.isPublished), isTrue);
  });

  test('★ 409 는 에러가 아니라 "이미 확정됨" — 버튼을 다시 살리지 않는다', () async {
    final repository = FakeRoutingRepository(
      proposal: AutoAssignResult(
        plans: [planOf(id: 2)],
        excludedStudentNames: const [],
      ),
      confirmError: ApiException.fromStatus(409, '초안·추천 상태에서만 승인할 수 있습니다'),
    );
    final container = containerWith(repository);
    await container.read(adminDispatchControllerProvider.future);
    await container.read(adminDispatchControllerProvider.notifier).propose();

    await container.read(adminDispatchControllerProvider.notifier).confirm();
    final async = container.read(adminDispatchControllerProvider);

    expect(async.hasError, isFalse, reason: '실패 화면으로 넘기지 않는다');
    expect(async.value!.alreadyConfirmed, isTrue);
    expect(
      async.value!.canConfirm,
      isFalse,
      reason: '재시도해도 같은 409 — 목록 새로고침으로 유도한다',
    );
  });

  test('409 가 아닌 실패는 그대로 에러로 올린다 — 조용히 삼키지 않는다', () async {
    final repository = FakeRoutingRepository(
      proposal: AutoAssignResult(
        plans: [planOf(id: 2)],
        excludedStudentNames: const [],
      ),
      confirmError: ApiException.fromStatus(500),
    );
    final container = containerWith(repository);
    await container.read(adminDispatchControllerProvider.future);
    await container.read(adminDispatchControllerProvider.notifier).propose();

    await container.read(adminDispatchControllerProvider.notifier).confirm();
    final async = container.read(adminDispatchControllerProvider);

    expect(async.hasError, isTrue);
    expect((async.error! as ApiException).kind, ApiErrorKind.server);
  });

  test('★ 방향을 바꾸면 이전 제안을 버린다 — 안 버리면 하원 계획을 등원으로 확정한다', () async {
    final repository = FakeRoutingRepository(
      proposal: AutoAssignResult(
        plans: [planOf(id: 2)],
        excludedStudentNames: const [],
      ),
    );
    final container = containerWith(repository);
    await container.read(adminDispatchControllerProvider.future);
    await container.read(adminDispatchControllerProvider.notifier).propose();

    container
        .read(adminDispatchControllerProvider.notifier)
        .selectDirection(RouteDirection.dropoff);
    final state = container.read(adminDispatchControllerProvider).value!;

    expect(state.direction, RouteDirection.dropoff);
    expect(state.stage, DispatchStage.idle);
    expect(state.canConfirm, isFalse);
  });

  test('운행일을 바꿔도 같은 이유로 제안을 버린다', () async {
    final repository = FakeRoutingRepository(
      proposal: AutoAssignResult(
        plans: [planOf(id: 2)],
        excludedStudentNames: const [],
      ),
    );
    final container = containerWith(repository);
    await container.read(adminDispatchControllerProvider.future);
    await container.read(adminDispatchControllerProvider.notifier).propose();

    container
        .read(adminDispatchControllerProvider.notifier)
        .selectServiceDate(DateTime(2026, 7, 30));
    final state = container.read(adminDispatchControllerProvider).value!;

    expect(state.serviceDate, DateTime(2026, 7, 30));
    expect(state.stage, DispatchStage.idle);
  });

  test('확정 가능한 계획이 없으면 확정 요청을 아예 보내지 않는다', () async {
    final repository = FakeRoutingRepository(
      proposal: AutoAssignResult(
        plans: [planOf(id: 1, status: RoutePlanStatus.published)],
        excludedStudentNames: const [],
      ),
    );
    final container = containerWith(repository);
    await container.read(adminDispatchControllerProvider.future);
    await container.read(adminDispatchControllerProvider.notifier).propose();

    await container.read(adminDispatchControllerProvider.notifier).confirm();

    expect(repository.confirmedPlanIds, isNull);
  });
}
