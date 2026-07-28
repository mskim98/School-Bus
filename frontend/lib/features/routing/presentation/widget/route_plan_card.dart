import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
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
        // 카드 반경(20)과 어긋나면 눌렀을 때 잉크가 모서리를 넘어간다(§3.2).
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 글자 확대 200% 에서도 상태 칩이 밀려나지 않게 좌측만 접히게 둔다(§7-5).
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_bus,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '버스 #${plan.busId}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          plan.direction.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  RoutePlanStatusChip(status: plan.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '정차 ${plan.stops.length}곳 · ${plan.distanceLabel} · ${plan.durationLabel}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              // 날짜·회차는 카드가 세로로 쌓이는 목록이라 자릿수를 고정한다(§2.1 Mono).
              Text(
                '${plan.serviceDateLabel} · ${plan.version}회차',
                style: AppTypography.mono(
                  context,
                ).copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 승인 단계 배지. 배포된 것과 제안일 뿐인 것이 목록에 섞여 있어 구분이 필요하다.
///
/// 공개 위젯인 이유 — 노선 상세 헤더도 같은 표기를 쓴다. 상태 표기를 화면마다
/// 다시 만들면 같은 단계가 두 곳에서 다른 색으로 보인다(§4 전제와 같은 이유).
class RoutePlanStatusChip extends StatelessWidget {
  const RoutePlanStatusChip({super.key, required this.status});

  final RoutePlanStatus status;

  @override
  Widget build(BuildContext context) {
    // 색만으로 구분하지 않는다(§0-1) — 아이콘·한글 라벨을 항상 함께 낸다.
    // primary 가 두 단계에 걸리는 건 의도다. 구분은 라벨이 하고, 색은
    // "아직 제안 단계"(회색) / "진행 중"(파랑) / "기사에게 배포됨"(초록)만 나눈다.
    final (String icon, AppTone tone) = switch (status) {
      RoutePlanStatus.draft => ('·', AppTone.neutral),
      RoutePlanStatus.recommended => ('◎', AppTone.primary),
      RoutePlanStatus.approved => ('✓', AppTone.primary),
      RoutePlanStatus.published => ('✓', AppTone.success),
    };

    return AppStatusChip(icon: icon, label: status.label, tone: tone);
  }
}
