import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
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
    // 색은 의미 톤으로만 고른다 — 화면에서 색을 새로 만들지 않는다(§5.1).
    // 아이콘 문자를 같이 내는 건 색만으로 상태를 구분하지 않기 위해서다(§0-1).
    final (
      String icon,
      String label,
      AppTone tone,
    ) = switch (connection.status) {
      StompConnectionStatus.connected => ('◉', '실시간 연결됨', AppTone.primary),
      StompConnectionStatus.connecting => ('◌', '연결 중', AppTone.neutral),
      StompConnectionStatus.reconnecting => ('↻', '재연결 중', AppTone.warning),
      StompConnectionStatus.disconnected => ('✕', '연결 끊김', AppTone.error),
    };
    final showRetry =
        onReconnect != null &&
        connection.status == StompConnectionStatus.disconnected;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppStatusChip(
          icon: icon,
          // 끊긴 사유가 있으면 함께 보여준다. 없으면 상태 이름만.
          label: connection.message == null
              ? label
              : '$label · ${connection.message}',
          tone: tone,
        ),
        if (showRetry) ...[
          const SizedBox(width: AppSpacing.sm),
          TextButton(onPressed: onReconnect, child: const Text('다시 연결')),
        ],
      ],
    );
  }
}
