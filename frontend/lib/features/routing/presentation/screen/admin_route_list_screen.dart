import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/async_section.dart';
import '../../../../core/ui/empty_view.dart';
import '../../application/admin_route_list_controller.dart';
import '../../application/admin_tenant_provider.dart';
import '../../domain/route_plan.dart';
import '../widget/admin_tenant_badge.dart';
import '../widget/route_plan_card.dart';
import '../widget/route_plan_map.dart';
import '../widget/route_stop_tile.dart';

/// 관리자: 노선 목록 + 상세(C11).
///
/// 목록과 상세를 **한 화면**에서 다룬다. 관리자는 데스크톱으로 보는 게 전제라
/// 넓은 화면에서는 좌측 목록 + 우측 상세가 자연스럽고, 오갈 때마다 목록을 다시
/// 조회하지 않아도 된다.
///
/// 선택한 계획은 URL(`/admin/routes/:id`)에 실린다 — 새로고침·뒤로가기가 그대로
/// 동작하고 특정 노선 링크를 그대로 공유할 수 있다.
class AdminRouteListScreen extends ConsumerWidget {
  const AdminRouteListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(adminTenantProvider);
    if (tenant == null) {
      return const EmptyView(
        icon: Icons.lock_outline,
        title: '관리자 전용 화면입니다',
        description: '관리자 계정으로 로그인하면 노선을 볼 수 있습니다.',
      );
    }

    final selectedId = _selectedPlanId(context);
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;

    // 좁은 화면: 목록과 상세를 한 번에 하나씩. 넓은 화면: 좌우로 나란히.
    if (!isWide) {
      return selectedId == null
          ? _PlanListPane(tenant: tenant, selectedId: null)
          : _PlanDetailPane(planId: selectedId, showBackButton: true);
    }

    return Row(
      children: [
        SizedBox(
          width: 380,
          child: _PlanListPane(tenant: tenant, selectedId: selectedId),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: selectedId == null
              ? const _NoSelection()
              : _PlanDetailPane(planId: selectedId, showBackButton: false),
        ),
      ],
    );
  }

  /// 라우터의 `/admin/routes/:id` 경로 파라미터. 목록만 보고 있으면 null.
  ///
  /// 라우터가 상세 경로에도 이 화면을 물려 두었기 때문에, 어느 계획을 펼칠지는
  /// 여기서 직접 읽는다.
  static int? _selectedPlanId(BuildContext context) {
    final raw = GoRouterState.of(context).pathParameters['id'];
    return raw == null ? null : int.tryParse(raw);
  }
}

class _PlanListPane extends ConsumerWidget {
  const _PlanListPane({required this.tenant, required this.selectedId});

  final AdminTenant tenant;
  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(adminRoutePlansProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              AdminTenantBadge(tenant: tenant),
              const Spacer(),
              IconButton(
                tooltip: '새로고침',
                onPressed: () =>
                    ref.read(adminRoutePlansProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncSection(
            value: plans,
            onRetry: () => ref.read(adminRoutePlansProvider.notifier).refresh(),
            data: (state) => state.isEmpty
                ? const EmptyView(
                    icon: Icons.route_outlined,
                    title: '아직 만들어진 노선이 없습니다',
                    description: '배차 화면에서 제안을 받고 확정하면 이곳에 노선이 쌓입니다.',
                  )
                : _PlanList(state: state, selectedId: selectedId),
          ),
        ),
      ],
    );
  }
}

class _PlanList extends ConsumerWidget {
  const _PlanList({required this.state, required this.selectedId});

  final AdminRoutePlansState state;
  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBusId = ref.watch(adminRouteBusFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 버스가 한 대뿐이면 필터가 의미 없다.
        if (state.busIds.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: selectedBusId == null,
                  onSelected: (_) => ref
                      .read(adminRouteBusFilterProvider.notifier)
                      .select(null),
                ),
                for (final busId in state.busIds)
                  ChoiceChip(
                    label: Text('버스 #$busId'),
                    selected: selectedBusId == busId,
                    onSelected: (_) => ref
                        .read(adminRouteBusFilterProvider.notifier)
                        .select(busId),
                  ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.plans.length,
            itemBuilder: (context, index) {
              final plan = state.plans[index];
              return RoutePlanCard(
                plan: plan,
                selected: plan.id == selectedId,
                onTap: () => context.go(AppRoutes.adminRouteDetailOf(plan.id)),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 노선 상세 — 지도(경로 + 정차 마커) + 정차 순서 목록.
class _PlanDetailPane extends ConsumerWidget {
  const _PlanDetailPane({required this.planId, required this.showBackButton});

  final int planId;
  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminRoutePlanDetailProvider(planId));

    return AsyncSection(
      value: detail,
      onRetry: () => ref.invalidate(adminRoutePlanDetailProvider(planId)),
      data: (plan) => _PlanDetail(plan: plan, showBackButton: showBackButton),
    );
  }
}

class _PlanDetail extends StatelessWidget {
  const _PlanDetail({required this.plan, required this.showBackButton});

  final RoutePlan plan;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DetailHeader(plan: plan, showBackButton: showBackButton),
        // 지도가 절반 — 정차 목록만으로는 노선 모양이 읽히지 않는다.
        Expanded(flex: 5, child: RoutePlanMap(plans: [plan])),
        Expanded(
          flex: 4,
          child: plan.stops.isEmpty
              ? const EmptyView(
                  icon: Icons.wrong_location_outlined,
                  title: '정차 지점이 없습니다',
                  description: '배차 화면에서 다시 제안을 받으면 정차 순서가 채워집니다.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  itemCount: plan.stops.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => RouteStopTile(
                    stop: plan.stops[index],
                    isLast: index == plan.stops.length - 1,
                  ),
                ),
        ),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.plan, required this.showBackButton});

  final RoutePlan plan;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              tooltip: '목록으로',
              onPressed: () => context.go(AppRoutes.adminRoutes),
              icon: const Icon(Icons.arrow_back),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '버스 #${plan.busId} · ${plan.direction.label} · ${plan.status.label}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs / 2),
                Text(
                  '${plan.serviceDateLabel} · ${plan.version}회차 · '
                  '정차 ${plan.stops.length}곳 · ${plan.distanceLabel} · ${plan.durationLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSelection extends StatelessWidget {
  const _NoSelection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        '왼쪽에서 노선을 선택하면 경로와 정차 순서를 볼 수 있습니다',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
      ),
    );
  }
}
