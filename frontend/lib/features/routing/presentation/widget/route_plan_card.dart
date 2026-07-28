import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/route_plan.dart';
import '../../domain/route_plan_status.dart';

/// 노선 계획 한 건 요약 — 배차 검토 목록과 노선 목록이 함께 쓴다.
///
/// ⚠️ **버스 이름을 못 보여준다.** 노선 API 는 `busId` 만 주고 이름은 버스 API 에만 있다.
/// 정차의 학생 이름이 없는 것과 같은 제약이라 표기 방식을 맞춰 `#id` 로 둔다.
class RoutePlanCard extends StatelessWidget {
  const RoutePlanCard({
    super.key,
    required this.plan,
    this.selected = false,
    this.onTap,
  });

  final RoutePlan plan;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      color: selected ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_bus, size: 18, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '버스 #${plan.busId}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    plan.direction.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const Spacer(),
                  _StatusChip(status: plan.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '정차 ${plan.stops.length}곳 · ${plan.distanceLabel} · ${plan.durationLabel}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(
                '${plan.serviceDateLabel} · ${plan.version}회차',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 승인 단계 배지. 배포된 것과 제안일 뿐인 것이 목록에 섞여 있어 구분이 필요하다.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RoutePlanStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 색만으로 구분하지 않는다 — 라벨(한글)을 항상 함께 쓴다.
    final (background, foreground) = status.isPublished
        ? (scheme.primary, scheme.onPrimary)
        : (scheme.surfaceContainerHighest, scheme.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        status.label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
