import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import 'app_tone.dart';

/// 연결 끊김 배너.
///
/// **앱을 못 쓰게 막지 않는다**(`docs/DESIGN_SYSTEM.md` §6). 기사는 지하차도나
/// 음영 지역을 자주 지나는데, 그때마다 화면을 덮어 버리면 정작 승하차를
/// 기록해야 할 순간에 아무것도 못 한다. 상단에 얇게 붙어 사실만 알린다.
///
/// ⚠️ **문구를 시안 그대로 쓰지 않았다.** 시안은 `기록은 저장 후 재전송됩니다`
/// 인데 이 클라이언트에는 재전송 큐가 없다 — 그대로 쓰면 사용자에게 거짓 안심을
/// 준다. 큐를 구현하면 그때 문구를 바꾼다(§8).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.message = '연결이 끊겼습니다 · 기록이 전송되지 않을 수 있습니다',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTone.error.container(context),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smd,
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: 18,
                color: AppTone.error.onContainer(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTone.error.onContainer(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
