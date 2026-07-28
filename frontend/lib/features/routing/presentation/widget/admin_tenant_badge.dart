import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../application/admin_tenant_provider.dart';

/// 지금 어느 학원을 보고 있는지 알려주는 배지.
///
/// 플랫폼 관리자는 소속 학원이 없어 코드에 박힌 기본값으로 조회한다(계획서 §8 D3).
/// 그 사실을 화면에 드러내지 않으면 "전체 학원을 보고 있다"고 오해한다.
class AdminTenantBadge extends StatelessWidget {
  const AdminTenantBadge({super.key, required this.tenant});

  final AdminTenant tenant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.apartment, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '학원 #${tenant.id}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (tenant.isFixedFallback) ...[
            const SizedBox(width: AppSpacing.xs),
            Tooltip(
              message: '플랫폼 관리자는 소속 학원이 없어 기본 학원으로 고정됩니다(MVP). 학원 선택은 MVP 이후.',
              child: Text(
                '고정값',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
