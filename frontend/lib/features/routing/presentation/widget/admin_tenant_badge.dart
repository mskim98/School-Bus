import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../application/admin_tenant_provider.dart';

/// 지금 어느 학원을 보고 있는지 알려주는 배지.
///
/// 플랫폼 관리자는 소속 학원이 없어 코드에 박힌 기본값으로 조회한다(계획서 §8 D3).
/// 그 사실을 화면에 드러내지 않으면 "전체 학원을 보고 있다"고 오해한다.
///
/// "고정값"을 [AppTone.warning] 태그로 떼어 낸 이유 — 학원 번호와 같은 회색으로
/// 붙여 두면 번호의 일부처럼 읽힌다. 이건 **주의해서 봐야 할 사실**이다.
class AdminTenantBadge extends StatelessWidget {
  const AdminTenantBadge({super.key, required this.tenant});

  final AdminTenant tenant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = AppTone.neutral.onContainer(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
                '학원 #${tenant.id}',
                style: theme.textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
        if (tenant.isFixedFallback) ...[
          const SizedBox(width: AppSpacing.sm),
          const Tooltip(
            message: '플랫폼 관리자는 소속 학원이 없어 기본 학원으로 고정됩니다(MVP). 학원 선택은 MVP 이후.',
            child: AppTag(label: '고정값', tone: AppTone.warning),
          ),
        ],
      ],
    );
  }
}
