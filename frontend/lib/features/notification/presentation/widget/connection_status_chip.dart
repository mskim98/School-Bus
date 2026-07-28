import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ws/spec/stomp_gateway.dart';

/// 실시간 연결 상태 표시.
///
/// 이걸 굳이 보여주는 이유 — 알림이 안 오는 게 "일이 안 일어나서"인지 "연결이 끊겨서"인지
/// 사용자가 구분할 수 없으면 화면을 믿을 수 없게 된다.
class ConnectionStatusChip extends StatelessWidget {
  const ConnectionStatusChip({
    super.key,
    required this.connection,
    this.onReconnect,
  });

  final StompConnectionState connection;

  /// 재시도를 접은 상태(연결 끊김)에서만 노출한다.
  final VoidCallback? onReconnect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 색은 전부 테마 스킴에서 가져온다 — 화면에서 색을 새로 만들지 않는다(컨벤션 §8).
    final (label, color) = switch (connection.status) {
      StompConnectionStatus.connected => ('실시간 연결됨', scheme.primary),
      StompConnectionStatus.connecting => ('연결 중', scheme.onSurfaceVariant),
      StompConnectionStatus.reconnecting => ('재연결 중', scheme.tertiary),
      StompConnectionStatus.disconnected => ('연결 끊김', scheme.error),
    };
    final showRetry =
        onReconnect != null &&
        connection.status == StompConnectionStatus.disconnected;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.sm,
          height: AppSpacing.sm,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          // 끊긴 사유가 있으면 함께 보여준다. 없으면 상태 이름만.
          connection.message == null ? label : '$label · ${connection.message}',
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
        if (showRetry) ...[
          const SizedBox(width: AppSpacing.sm),
          TextButton(onPressed: onReconnect, child: const Text('다시 연결')),
        ],
      ],
    );
  }
}
