import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/routing_repository.dart';
import '../domain/auto_assign_result.dart';
import '../domain/route_plan.dart';
import 'admin_route_list_controller.dart';
import 'admin_tenant_provider.dart';

/// 배차 흐름의 현재 단계. 화면이 단계 표시(제안 → 검토 → 확정)를 그리는 근거다.
enum DispatchStage {
  /// 아직 제안을 받지 않음
  idle,

  /// 제안을 받아 검토 중 — **이 시점엔 학생 배정이 바뀌지 않았다**
  review,

  /// 확정 완료(배정 커밋 + 승인 + 배포)
  confirmed,
}

class AdminDispatchState {
  const AdminDispatchState({
    this.direction = RouteDirection.pickup,
    this.serviceDate,
    this.proposal,
    this.confirmed = const [],
    this.alreadyConfirmed = false,
  });

  final RouteDirection direction;

  /// null 이면 오늘 — 서버 기본값에 맡긴다.
  final DateTime? serviceDate;

  /// 받아온 제안. null 이면 아직 제안 전이다.
  final AutoAssignResult? proposal;

  /// 확정으로 배포까지 끝난 계획들.
  final List<RoutePlan> confirmed;

  /// 확정 요청이 **409** 로 거절됨 = 이 제안은 이미 확정된 것.
  ///
  /// 에러 화면으로 넘기지 않는 이유: 실패가 아니라 "이미 됐다"는 뜻이라
  /// 사용자가 할 일은 재시도가 아니라 목록 확인이다(계획서 §3.2).
  final bool alreadyConfirmed;

  DispatchStage get stage {
    if (confirmed.isNotEmpty) return DispatchStage.confirmed;
    return proposal == null ? DispatchStage.idle : DispatchStage.review;
  }

  /// 확정 버튼을 누를 수 있는가. 409 를 받은 뒤에는 다시 살리지 않는다.
  bool get canConfirm =>
      !alreadyConfirmed && (proposal?.confirmablePlanIds.isNotEmpty ?? false);

  AdminDispatchState confirmedWith(List<RoutePlan> plans) => AdminDispatchState(
    direction: direction,
    serviceDate: serviceDate,
    proposal: proposal,
    confirmed: plans,
  );

  AdminDispatchState markAlreadyConfirmed() => AdminDispatchState(
    direction: direction,
    serviceDate: serviceDate,
    proposal: proposal,
    alreadyConfirmed: true,
  );
}

/// 관리자: 배차 제안 → 검토 → 확정(C10).
///
/// `approve`/`publish` 는 부르지 않는다 — 확정(`auto-assign/confirm`) 하나가
/// 배정 커밋·승인·배포를 모두 처리한다(계획서 §4.3).
class AdminDispatchController extends AsyncNotifier<AdminDispatchState> {
  @override
  Future<AdminDispatchState> build() async {
    // 로그인/학원이 바뀌면 이전 제안은 남겨두면 안 된다.
    ref.watch(adminTenantProvider);
    return const AdminDispatchState();
  }

  /// 등원/하원 전환. 방향이 바뀌면 이전 제안은 버린다 —
  /// 다른 방향의 계획을 그대로 두면 그걸 확정해 버리는 사고가 난다.
  void selectDirection(RouteDirection direction) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      AdminDispatchState(
        direction: direction,
        serviceDate: current.serviceDate,
      ),
    );
  }

  /// 운행일 변경. null 이면 오늘. 방향과 같은 이유로 제안을 버린다.
  void selectServiceDate(DateTime? serviceDate) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      AdminDispatchState(
        direction: current.direction,
        serviceDate: serviceDate,
      ),
    );
  }

  /// 제안 받기 — 서버가 버스별 `RECOMMENDED` 계획을 만들어 돌려준다.
  Future<void> propose() async {
    final current = state.value;
    if (current == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final tenant = _requireTenant();
      final result = await ref
          .read(routingRepositoryProvider)
          .autoAssign(
            tenantId: tenant.id,
            direction: current.direction,
            serviceDate: current.serviceDate,
          );
      return AdminDispatchState(
        direction: current.direction,
        serviceDate: current.serviceDate,
        proposal: result,
      );
    });
  }

  /// 확정 — 배정 커밋 + 승인 + 배포가 한 번에 일어난다.
  Future<void> confirm() async {
    final current = state.value;
    if (current == null) return;

    final planIds = current.proposal?.confirmablePlanIds ?? const <int>[];
    if (planIds.isEmpty) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        final published = await ref
            .read(routingRepositoryProvider)
            .confirmAutoAssign(planIds: planIds);
        // 배포까지 끝났으니 노선 목록이 낡았다.
        ref.invalidate(adminRoutePlansProvider);
        return current.confirmedWith(published);
      } on ApiException catch (e) {
        // 409 는 실패가 아니라 "이미 확정됨"이다. 버튼을 되살리면 같은 요청을
        // 반복하게 되므로 잠그고 목록을 새로 읽는다(계획서 §3.2).
        // 분기는 status(kind)로만 한다 — message 문자열은 보지 않는다(컨벤션 §7-1).
        if (e.kind != ApiErrorKind.conflict) rethrow;
        ref.invalidate(adminRoutePlansProvider);
        return current.markAlreadyConfirmed();
      }
    });
  }

  /// 확정 후 다시 제안부터 시작.
  void reset() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      AdminDispatchState(
        direction: current.direction,
        serviceDate: current.serviceDate,
      ),
    );
  }

  /// 관리자 세션이 없으면 조회 대상 학원을 정할 수 없다.
  ///
  /// 라우터 가드가 막고 있어 실제로는 닿지 않는 경로지만, 조용히 넘어가면
  /// 버튼을 눌러도 아무 일이 안 일어나는 화면이 된다 — 에러로 드러낸다.
  AdminTenant _requireTenant() {
    final tenant = ref.read(adminTenantProvider);
    if (tenant == null) {
      throw StateError('관리자 세션이 없어 학원을 정할 수 없습니다');
    }
    return tenant;
  }
}

final adminDispatchControllerProvider =
    AsyncNotifierProvider<AdminDispatchController, AdminDispatchState>(
      AdminDispatchController.new,
    );
