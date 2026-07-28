import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// 빈 상태 표시 — **에러가 아니다**(컨벤션 §7-4).
///
/// 빈 배열은 정상 응답이다. 결석 처리로 명단이 비거나 아직 노선이 배포되지 않은
/// 상태를 에러로 그리면, 사용자는 고장 났다고 생각하고 새로고침만 반복한다.
///
/// [description] 에는 **사용자가 지금 무엇을 하면 되는지**를 적는다.
/// "데이터가 없습니다" 로 끝내면 기다려야 하는 상황인지 요청해야 하는 상황인지 알 수 없다.
/// [action] 은 그 행동을 화면 안에서 바로 할 수 있을 때만 준다.
///
/// 모양은 `docs/DESIGN_SYSTEM.md` §6 — 원형 아이콘 48 + 제목 + 설명 + 다음 행동.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = this.action;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppTouch.min,
              height: AppTouch.min,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.smd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
