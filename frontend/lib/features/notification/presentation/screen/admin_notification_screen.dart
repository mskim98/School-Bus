import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/async_section.dart';
import '../../../../core/ui/empty_view.dart';
import '../../../../core/ui/error_message.dart';
import '../../../../core/ui/offline_banner.dart';
import '../../../../core/ui/skeleton_box.dart';
import '../../../../core/ws/spec/stomp_gateway.dart';
import '../../application/notification_feed_controller.dart';
import '../widget/connection_status_chip.dart';
import '../widget/notification_tile.dart';

/// 알림함(관리자, 데스크톱 뷰).
///
/// **REST 로 이력을 먼저 채우고 WebSocket 으로 새 알림을 덧붙인다** — WS 는 연결된
/// 시점 이후의 변화만 주기 때문이다(MVP_API_SPEC §7.5). 순서와 구독 정리는
/// [NotificationFeedController] 가 책임지고, 이 화면은 표시만 한다(컨벤션 §3).
///
/// ⚠️ 클래스 이름·파일 경로는 라우터가 가리키고 있어 바꾸지 않는다.
class AdminNotificationScreen extends ConsumerWidget {
  const AdminNotificationScreen({super.key});

  /// 데스크톱에서 목록이 화면 폭 전체로 늘어나면 눈이 줄을 따라가지 못한다.
  static const _maxContentWidth = 880.0;

  /// 알림 한 줄의 대략 높이 — 로딩 자리표시자가 실제 목록과 어긋나면 화면이 튄다.
  static const _tileHeight = 84.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationFeedControllerProvider);
    final controller = ref.read(notificationFeedControllerProvider.notifier);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          // 이력 조회 자체가 실패하면 보여줄 게 없으니 화면 전체가 에러다.
          // (실시간 스트림만 끊긴 경우는 아래 [_FeedBody] 의 인라인 배너로 처리한다.)
          child: AsyncSection<NotificationFeedState>(
            value: feed,
            onRetry: controller.refresh,
            loading: () => const SkeletonList(
              itemCount: 5,
              itemHeight: _tileHeight,
              // 툴바 자리를 미리 잡아 둔다 — 로딩이 끝날 때 목록이 아래로 밀리지 않게.
              header: AppTouch.min,
              padding: EdgeInsets.zero,
            ),
            data: (state) => _FeedBody(state: state, controller: controller),
          ),
        ),
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({required this.state, required this.controller});

  final NotificationFeedState state;
  final NotificationFeedController controller;

  @override
  Widget build(BuildContext context) {
    final isOffline =
        state.connection.status == StompConnectionStatus.disconnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(state: state, controller: controller),
        const SizedBox(height: AppSpacing.md),
        // ⚠️ 실시간이 끊겼다고 화면을 덮지 않는다 — 이미 받아둔 알림까지 못 보게 되면
        // 그게 회귀다. 목록은 그대로 두고 위에 사실만 알린다(§6 오프라인).
        if (isOffline) ...[
          const OfflineBanner(message: '실시간 연결이 끊겼습니다 · 새 알림이 바로 뜨지 않을 수 있습니다'),
          const SizedBox(height: AppSpacing.md),
        ],
        if (state.liveError != null) ...[
          ErrorBanner(error: state.liveError!, onRetry: controller.refresh),
          const SizedBox(height: AppSpacing.md),
        ],
        Expanded(
          child: state.isEmpty
              // 빈 배열은 에러가 아니다(컨벤션 §7-4) — 아직 아무 일도 없었을 뿐이다.
              ? const EmptyView(
                  icon: Icons.notifications_none,
                  title: '받은 알림이 없습니다',
                  description:
                      '승하차·SOS 같은 일이 생기면 이곳에 바로 쌓입니다. 그대로 두고 기다리면 됩니다.',
                )
              : _FeedList(state: state, controller: controller),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state, required this.controller});

  final NotificationFeedState state;
  final NotificationFeedController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConnectionStatusChip(
          connection: state.connection,
          onReconnect: controller.refresh,
        ),
        if (state.tenantId != null) ...[
          AppTag(label: '학원 #${state.tenantId}', tone: AppTone.neutral),
          // 플랫폼 관리자는 소속 학원이 없어 한 곳으로 고정해 둔 상태다(계획서 §8 D3).
          // 고정값이라는 사실을 숨기면 "왜 다른 학원이 안 보이지"로 오해한다.
          if (state.isTenantPinned)
            const AppTag(label: '고정값', tone: AppTone.warning),
        ],
        TextButton.icon(
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('새로고침'),
        ),
        if (state.justArrivedIds.isNotEmpty)
          TextButton(
            onPressed: controller.clearHighlights,
            child: const Text('새 표시 지우기'),
          ),
      ],
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({required this.state, required this.controller});

  final NotificationFeedState state;
  final NotificationFeedController controller;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: state.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = state.items[index];
        return NotificationTile(
          notification: item,
          isNew: state.justArrivedIds.contains(item.id),
        );
      },
    );
  }
}
