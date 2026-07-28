import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../api/api_exception.dart';
import 'app_tone.dart';

/// 예외를 사용자에게 보여줄 문구로 바꾼다.
///
/// 화면마다 다르게 만들지 않는다(컨벤션 §7-3) — 문구가 제각각이면 같은 실패를
/// 사용자가 다른 문제로 오해한다.
String messageOf(Object error) {
  if (error is ApiException) return error.message;
  return '알 수 없는 오류가 발생했습니다';
}

/// 화면 전체가 실패했을 때의 에러 표시.
///
/// 모양은 `docs/DESIGN_SYSTEM.md` §6 — 원형 아이콘 48 + **서버 문구 그대로** +
/// 다시 시도. 서버 `message` 를 다시 쓰지 않는 게 규칙이다(컨벤션 §7-2):
/// 백엔드 응답에 머신리더블 `errorCode` 가 없어서, 우리가 문구를 갈아끼우면
/// 사용자가 무엇 때문에 막혔는지 알 방법이 아예 사라진다.
///
/// 목록 일부만 실패한 경우처럼 화면이 살아 있을 때는 이걸 쓰지 말고
/// [ErrorBanner] 를 인라인으로 얹는다 — 화면을 덮으면 이미 받아둔 내용까지
/// 못 보게 되는 회귀가 생긴다.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onRetry = this.onRetry;

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
                color: AppTone.error.container(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.priority_high,
                size: 24,
                color: AppTone.error.onContainer(context),
              ),
            ),
            const SizedBox(height: AppSpacing.smd),
            Text(
              messageOf(error),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ],
        ),
      ),
    );
  }
}

/// 인라인 에러 표시(폼 하단, 목록 위 등).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final foreground = AppTone.error.onContainer(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppTone.error.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              messageOf(error),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: const Text('다시 시도'),
            ),
        ],
      ),
    );
  }
}
