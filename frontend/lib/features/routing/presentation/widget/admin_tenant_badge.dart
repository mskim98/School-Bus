import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../application/admin_tenant_provider.dart';

/// 지금 어느 학원을 보고 있는지 알려주고, 고를 수 있으면 **고르게 한다**.
///
/// 학원 관리자는 소속 학원 하나에 묶여 있어 표시만 한다. 플랫폼 관리자는 소속이
/// 없어 예전에는 코드에 박힌 기본 학원으로 고정됐는데, `GET /api/tenants` 가
/// 실재하는 걸 확인해(2026-07-29) **선택 UI 로 바꿨다.**
///
/// 어느 쪽이든 "지금 보고 있는 학원"이 화면에 항상 떠 있어야 한다 — 배차는
/// 되돌리기 어려운 동작이라, 엉뚱한 학원에 확정하는 사고를 막는 게 이 위젯의 일이다.
class AdminTenantBadge extends ConsumerWidget {
  const AdminTenantBadge({super.key, required this.tenant});

  final AdminTenant tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tenant.canSwitch)
          _TenantSelector(tenant: tenant)
        else
          _TenantLabel(tenant: tenant),
        if (tenant.isFixedFallback) ...[
          const SizedBox(width: AppSpacing.sm),
          const Tooltip(
            message: '학원 목록을 받지 못해 기본 학원으로 조회 중입니다. 다른 학원의 데이터가 아닙니다.',
            child: AppTag(label: '고정값', tone: AppTone.warning),
          ),
        ],
      ],
    );
  }
}

/// 바꿀 수 없는 학원 — 읽기 전용 배지.
class _TenantLabel extends StatelessWidget {
  const _TenantLabel({required this.tenant});

  final AdminTenant tenant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = AppTone.neutral.onContainer(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppTone.neutral.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment, size: 16, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            // 이름을 알면 이름이 낫다 — `학원 #2` 로는 어느 학원인지 아무도 모른다.
            tenant.name ?? '학원 #${tenant.id}',
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// 플랫폼 관리자용 학원 선택.
class _TenantSelector extends ConsumerWidget {
  const _TenantSelector({required this.tenant});

  final AdminTenant tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(adminTenantOptionsProvider).value ?? const [];
    if (options.isEmpty) return _TenantLabel(tenant: tenant);

    return ConstrainedBox(
      // 목록 항목과 마찬가지로 48dp 를 지킨다 — 관제는 태블릿에서도 쓴다(§3.3).
      constraints: const BoxConstraints(minHeight: AppTouch.min),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: tenant.id,
          icon: const Icon(Icons.expand_more),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onChanged: (id) {
            if (id == null) return;
            ref.read(selectedTenantIdProvider.notifier).select(id);
          },
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apartment, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Text(option.name),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
