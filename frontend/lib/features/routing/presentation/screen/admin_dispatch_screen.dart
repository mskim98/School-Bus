import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_action_button.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/async_section.dart';
import '../../../../core/ui/empty_view.dart';
import '../../../../core/ui/skeleton_box.dart';
// ⚠️ 다른 feature 의 `application/` 을 읽는다 — 컨벤션 §9 C-1 의 **허용 예외**다.
// 조건 셋을 모두 지킨다: ① 읽는 쪽이 `presentation/` ② `ref.watch` 만 하고 저쪽
// 컨트롤러의 메서드는 부르지 않는다 ③ 명부가 없어도 이 화면은 그려진다
// (`버스 #1`·`#7` 로 뜨고 정원 칸만 빈다).
import '../../../bus/application/bus_directory.dart';
import '../../../student/application/student_directory.dart';
import '../../application/admin_dispatch_controller.dart';
import '../../application/admin_tenant_provider.dart';
import '../../domain/auto_assign_result.dart';
import '../../domain/route_plan.dart';
import '../widget/admin_tenant_badge.dart';
import '../widget/bus_assignment_card.dart';
import '../widget/excluded_students_banner.dart';
import '../widget/route_plan_map.dart';

/// 관리자: 배차 — 제안 → 검토 → 확정(C10).
///
/// 제안(`auto-assign`)은 **아직 아무것도 바꾸지 않는다.** 학생 배정 커밋·승인·배포는
/// 전부 확정(`auto-assign/confirm`) 한 번에 일어난다. 이 차이를 화면이 분명히 해야
/// 관리자가 "제안만 받고 끝냈는데 왜 기사에게 안 보이지"를 겪지 않는다.
///
/// 그래서 헤더에 단계 표시([_StageSteps])를 세워 뒀다 — 지금 어디까지 왔는지가
/// 한눈에 안 보이면 "제안 = 완료"로 읽힌다.
class AdminDispatchScreen extends ConsumerWidget {
  const AdminDispatchScreen({super.key});

  /// 좁은 화면에서 지도에 내주는 높이.
  static const _mapPreviewHeight = 320.0;

  /// 노선 카드 한 장의 대략 높이 — 자리표시자가 실제와 어긋나면 화면이 튄다.
  static const _cardHeight = 132.0;

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
            // 제안 계산은 몇 초씩 걸린다 — 스피너보다 "무엇이 나타날지"를 보여준다(§6).
            loading: () =>
                const SkeletonList(itemCount: 3, itemHeight: _cardHeight),
            data: (state) => switch (state.stage) {
              DispatchStage.idle => const EmptyView(
                icon: Icons.alt_route_outlined,
                title: '아직 받은 제안이 없습니다',
                description:
                    '방향과 운행일을 고르고 "제안 받기"를 누르면 버스별 노선을 계산해 보여줍니다.\n'
                    '제안 단계에서는 학생 배정이 바뀌지 않습니다.',
              ),
              DispatchStage.review => _ReviewView(
                state: state,
                tenantId: tenant.id,
              ),
              DispatchStage.confirmed => _ConfirmedView(
                state: state,
                tenantId: tenant.id,
              ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StageSteps(stage: state?.stage ?? DispatchStage.idle),
          const SizedBox(height: AppSpacing.smd),
          Wrap(
            spacing: AppSpacing.sm,
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
              _ServiceDateField(
                serviceDate: state?.serviceDate,
                enabled: !isBusy,
              ),
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
        ],
      ),
    );
  }
}

/// 제안 → 검토 → 확정. **지금 어느 단계인지**만 알려주는 표시라 눌리지 않는다.
class _StageSteps extends StatelessWidget {
  const _StageSteps({required this.stage});

  final DispatchStage stage;

  static const _labels = ['1 제안', '2 검토', '3 확정'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = switch (stage) {
      DispatchStage.idle => 0,
      DispatchStage.review => 1,
      DispatchStage.confirmed => 2,
    };

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Icon(Icons.chevron_right, size: 16, color: scheme.onSurfaceVariant),
          AppTag(
            label: _labels[i],
            tone: i <= current ? AppTone.primary : AppTone.neutral,
            // 지금 단계만 진하게 — 지나온 단계와 앞으로 올 단계를 셋 다 구분한다.
            filled: i == current,
          ),
        ],
      ],
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
  const _ReviewView({required this.state, required this.tenantId});

  final AdminDispatchState state;
  final int tenantId;

  /// 검토 패널 폭. 노선 카드 한 장이 접히지 않고 들어가는 최소치다.
  static const _panelWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    final proposal = state.proposal;
    if (proposal == null) return const SizedBox.shrink();

    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final panel = _ReviewPanel(
      state: state,
      proposal: proposal,
      tenantId: tenantId,
    );
    final map = RoutePlanMap(plans: proposal.plans);

    if (!isWide) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          panel,
          const SizedBox(height: AppSpacing.md),
          SizedBox(height: AdminDispatchScreen._mapPreviewHeight, child: map),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: _panelWidth,
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
  const _ReviewPanel({
    required this.state,
    required this.proposal,
    required this.tenantId,
  });

  final AdminDispatchState state;
  final AutoAssignResult proposal;
  final int tenantId;

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
          Text('배정할 학생이 없어 만들어진 계획이 없습니다.', style: theme.textTheme.bodyLarge)
        else ...[
          Text(
            '버스 ${proposal.plans.length}대 · 배정 학생 ${proposal.totalStops}명',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.smd),
          _BusAssignmentList(tenantId: tenantId, plans: proposal.plans),
        ],

        const SizedBox(height: AppSpacing.md),
        if (state.alreadyConfirmed)
          const _AlreadyConfirmedNotice()
        else
          // 화면당 하나뿐인 주요 동작이라 56dp(§3.3). **되돌릴 수 없는 동작**이라
          // 검토 단계를 거치지 않고는 여기까지 오지 못한다.
          AppActionButton(
            icon: '✓',
            label: '이대로 확정하기',
            tone: AppTone.primary,
            primaryAction: true,
            // 확정 가능한 계획이 없으면 눌러도 서버가 거절한다 — 아예 막는다.
            onPressed: state.canConfirm
                ? () => ref
                      .read(adminDispatchControllerProvider.notifier)
                      .confirm()
                : null,
          ),
      ],
    );
  }
}

/// 버스 간 거리 비교 + 버스별 배정 카드. 검토·확정 두 화면이 함께 쓴다.
///
/// **명부는 거들 뿐이다.** 호차명·학생 이름·좌석 수가 아직 안 왔거나 실패해도
/// 카드는 `버스 #1`·`#7` 로 그려지고 정원 칸만 빈다 — 명부 때문에 제안 결과가
/// 가려지면 관리자가 확정 판단을 아예 못 한다(컨벤션 §9 C-1 예외 조건 ③).
class _BusAssignmentList extends ConsumerWidget {
  const _BusAssignmentList({required this.tenantId, required this.plans});

  final int tenantId;
  final List<RoutePlan> plans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buses =
        ref.watch(busDirectoryProvider(tenantId)).value ??
        const BusDirectory.empty();
    final students =
        ref.watch(studentDirectoryProvider(tenantId)).value ??
        const StudentDirectory.empty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 알고리즘이 거리 균형을 맞추지 않는다는 사실을 확정 **전에** 보여준다
        // (검증 보고서 L1·L2). 버스가 한 대뿐이면 스스로 사라진다.
        BusDistanceComparison(plans: plans, busNameOf: buses.nameOf),
        if (plans.length > 1) const SizedBox(height: AppSpacing.sm),
        for (final plan in plans)
          BusAssignmentCard(
            plan: plan,
            busName: buses.nameOf(plan.busId),
            seatCapacity: buses.seatCapacityOf(plan.busId),
            studentNameOf: students.nameOf,
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
    // 정보 배너는 primaryContainer 다(§1.1) — 경고가 아니라 안내다.
    final foreground = AppTone.primary.onContainer(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: AppTone.primary.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '아래는 아직 "제안"입니다. 학생 배정은 바뀌지 않았고 기사에게도 보이지 않습니다. '
              '확정을 눌러야 배정·승인·배포가 한 번에 처리됩니다.',
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.smd),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Text(
            '이미 확정된 계획입니다. 노선 목록에서 현재 상태를 확인해 주세요.',
            style: theme.textTheme.bodyLarge,
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
  const _ConfirmedView({required this.state, required this.tenantId});

  final AdminDispatchState state;
  final int tenantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final excluded = state.proposal?.excludedStudentNames ?? const <String>[];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle,
              // 끝났다는 뜻이라 success 다 — 파랑은 "진행 중"으로 읽힌다(§4).
              color: AppTone.success.solid(context),
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

        // 확정 뒤에도 같은 표기를 쓴다 — 방금 무엇을 배포했는지가 검토 화면과
        // 다르게 보이면 관리자가 배정이 바뀐 줄 안다.
        _BusAssignmentList(tenantId: tenantId, plans: state.confirmed),

        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: AdminDispatchScreen._mapPreviewHeight,
          child: RoutePlanMap(plans: state.confirmed),
        ),
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
