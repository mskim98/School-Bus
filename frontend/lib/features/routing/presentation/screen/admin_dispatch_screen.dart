import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/async_section.dart';
import '../../../../core/ui/empty_view.dart';
import '../../application/admin_dispatch_controller.dart';
import '../../application/admin_tenant_provider.dart';
import '../../domain/auto_assign_result.dart';
import '../../domain/route_plan.dart';
import '../widget/admin_tenant_badge.dart';
import '../widget/excluded_students_banner.dart';
import '../widget/route_plan_card.dart';
import '../widget/route_plan_map.dart';

/// 관리자: 배차 — 제안 → 검토 → 확정(C10).
///
/// 제안(`auto-assign`)은 **아직 아무것도 바꾸지 않는다.** 학생 배정 커밋·승인·배포는
/// 전부 확정(`auto-assign/confirm`) 한 번에 일어난다. 이 차이를 화면이 분명히 해야
/// 관리자가 "제안만 받고 끝냈는데 왜 기사에게 안 보이지"를 겪지 않는다.
class AdminDispatchScreen extends ConsumerWidget {
  const AdminDispatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenant = ref.watch(adminTenantProvider);
    final dispatch = ref.watch(adminDispatchControllerProvider);

    if (tenant == null) {
      return const EmptyView(
        icon: Icons.lock_outline,
        title: '관리자 전용 화면입니다',
        description: '관리자 계정으로 로그인하면 배차를 진행할 수 있습니다.',
      );
    }

    return Column(
      children: [
        _DispatchHeader(tenant: tenant),
        const Divider(height: 1),
        Expanded(
          child: AsyncSection(
            value: dispatch,
            onRetry: () =>
                ref.read(adminDispatchControllerProvider.notifier).propose(),
            data: (state) => switch (state.stage) {
              DispatchStage.idle => const EmptyView(
                icon: Icons.alt_route_outlined,
                title: '아직 받은 제안이 없습니다',
                description:
                    '방향과 운행일을 고르고 "제안 받기"를 누르면 버스별 노선을 계산해 보여줍니다.\n'
                    '제안 단계에서는 학생 배정이 바뀌지 않습니다.',
              ),
              DispatchStage.review => _ReviewView(state: state),
              DispatchStage.confirmed => _ConfirmedView(state: state),
            },
          ),
        ),
      ],
    );
  }
}

/// 조회 대상(학원·방향·운행일) + 제안 받기 버튼.
class _DispatchHeader extends ConsumerWidget {
  const _DispatchHeader({required this.tenant});

  final AdminTenant tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispatch = ref.watch(adminDispatchControllerProvider);
    final state = dispatch.value;
    final isBusy = dispatch.isLoading;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AdminTenantBadge(tenant: tenant),
          SegmentedButton<RouteDirection>(
            segments: [
              for (final d in RouteDirection.values)
                ButtonSegment(value: d, label: Text(d.label)),
            ],
            selected: {state?.direction ?? RouteDirection.pickup},
            onSelectionChanged: isBusy
                ? null
                : (selection) => ref
                      .read(adminDispatchControllerProvider.notifier)
                      .selectDirection(selection.first),
          ),
          _ServiceDateField(serviceDate: state?.serviceDate, enabled: !isBusy),
          FilledButton.icon(
            onPressed: isBusy
                ? null
                : () => ref
                      .read(adminDispatchControllerProvider.notifier)
                      .propose(),
            icon: const Icon(Icons.auto_awesome),
            label: Text(state?.proposal == null ? '제안 받기' : '다시 제안 받기'),
          ),
        ],
      ),
    );
  }
}

/// 운행일 선택. 비워두면 서버가 오늘로 처리한다.
class _ServiceDateField extends ConsumerWidget {
  const _ServiceDateField({required this.serviceDate, required this.enabled});

  final DateTime? serviceDate;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = serviceDate;
    final label = date == null ? '오늘' : RoutePlan.formatDate(date);

    return OutlinedButton.icon(
      onPressed: enabled ? () => _pick(context, ref) : null,
      icon: const Icon(Icons.event, size: 18),
      label: Text('운행일 $label'),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: serviceDate ?? today,
      // 지난 날짜로 배차를 새로 짤 일은 없다.
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked == null) return;
    ref
        .read(adminDispatchControllerProvider.notifier)
        .selectServiceDate(picked);
  }
}

/// 제안 검토 — 좌측 계획 목록, 우측 지도 미리보기.
class _ReviewView extends StatelessWidget {
  const _ReviewView({required this.state});

  final AdminDispatchState state;

  @override
  Widget build(BuildContext context) {
    final proposal = state.proposal;
    if (proposal == null) return const SizedBox.shrink();

    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final panel = _ReviewPanel(state: state, proposal: proposal);
    final map = RoutePlanMap(plans: proposal.plans);

    if (!isWide) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          panel,
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: 320, child: map),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 420,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: panel,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: map),
      ],
    );
  }
}

class _ReviewPanel extends ConsumerWidget {
  const _ReviewPanel({required this.state, required this.proposal});

  final AdminDispatchState state;
  final AutoAssignResult proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 좌표가 없어 빠진 학생 — 확정 전에 반드시 눈에 들어와야 한다.
        ExcludedStudentsBanner(studentNames: proposal.excludedStudentNames),
        if (proposal.hasExcludedStudents) const SizedBox(height: AppSpacing.md),

        const _ProposalNotice(),
        const SizedBox(height: AppSpacing.md),

        if (proposal.isEmpty)
          Text('배정할 학생이 없어 만들어진 계획이 없습니다.', style: theme.textTheme.bodyMedium)
        else ...[
          Text(
            '버스 ${proposal.plans.length}대 · 배정 학생 ${proposal.totalStops}명',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final plan in proposal.plans) RoutePlanCard(plan: plan),
        ],

        const SizedBox(height: AppSpacing.md),
        if (state.alreadyConfirmed)
          const _AlreadyConfirmedNotice()
        else
          FilledButton.icon(
            // 확정 가능한 계획이 없으면 눌러도 서버가 거절한다 — 아예 막는다.
            onPressed: state.canConfirm
                ? () => ref
                      .read(adminDispatchControllerProvider.notifier)
                      .confirm()
                : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('이대로 확정하기'),
          ),
      ],
    );
  }
}

/// "아직 아무것도 안 바뀌었다"를 명시한다 — 제안과 확정의 차이가 이 화면의 핵심이다.
class _ProposalNotice extends StatelessWidget {
  const _ProposalNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '아래는 아직 "제안"입니다. 학생 배정은 바뀌지 않았고 기사에게도 보이지 않습니다. '
              '확정을 눌러야 배정·승인·배포가 한 번에 처리됩니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 409 안내 — 재시도 버튼을 주지 않는다. 이미 처리된 요청이라 다시 보내도 결과가 같다.
class _AlreadyConfirmedNotice extends StatelessWidget {
  const _AlreadyConfirmedNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Text(
            '이미 확정된 계획입니다. 노선 목록에서 현재 상태를 확인해 주세요.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.go(AppRoutes.adminRoutes),
          icon: const Icon(Icons.route_outlined),
          label: const Text('노선 목록 보기'),
        ),
      ],
    );
  }
}

/// 확정 완료 — 배정 커밋 + 승인 + 배포가 모두 끝난 상태.
class _ConfirmedView extends ConsumerWidget {
  const _ConfirmedView({required this.state});

  final AdminDispatchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final excluded = state.proposal?.excludedStudentNames ?? const <String>[];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                '배차를 확정했습니다 — 노선 ${state.confirmed.length}건이 기사에게 배포됐습니다',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // 확정한 뒤에도 제외 학생은 계속 보여준다 — 여기서 놓치면 아무도 못 잡는다.
        ExcludedStudentsBanner(studentNames: excluded),
        if (excluded.isNotEmpty) const SizedBox(height: AppSpacing.md),

        for (final plan in state.confirmed) RoutePlanCard(plan: plan),

        const SizedBox(height: AppSpacing.md),
        SizedBox(height: 320, child: RoutePlanMap(plans: state.confirmed)),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.adminRoutes),
              icon: const Icon(Icons.route_outlined),
              label: const Text('노선 목록에서 보기'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(adminDispatchControllerProvider.notifier).reset(),
              icon: const Icon(Icons.refresh),
              label: const Text('다른 방향 배차하기'),
            ),
          ],
        ),
      ],
    );
  }
}
