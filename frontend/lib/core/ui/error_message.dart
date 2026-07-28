import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../api/api_exception.dart';

/// 예외를 사용자에게 보여줄 문구로 바꾼다.
///
/// 화면마다 다르게 만들지 않는다(컨벤션 §7-3) — 문구가 제각각이면 같은 실패를
/// 사용자가 다른 문제로 오해한다.
String messageOf(Object error) {
  if (error is ApiException) return error.message;
  return '알 수 없는 오류가 발생했습니다';
}

/// 화면 전체가 실패했을 때의 에러 표시 — [ErrorBanner] 를 가운데 놓는다.
///
/// 화면마다 `Center(child: Padding(child: ErrorBanner(...)))` 를 다시 쓰지 않기 위해
/// 여기 한 곳에 둔다(컨벤션 §7-3). 목록 일부만 실패한 경우처럼 화면이 살아 있을 때는
/// 이걸 쓰지 말고 [ErrorBanner] 를 인라인으로 얹는다.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ErrorBanner(error: error, onRetry: onRetry),
    ),
  );
}

/// 인라인 에러 표시(폼 하단, 목록 위 등).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              messageOf(error),
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}
