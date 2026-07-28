import 'package:flutter/material.dart';

import '../../../../core/ui/pending_screen.dart';

/// 알림 — REST 로 이력을 먼저 채우고 WebSocket 으로 새 알림을 덧붙인다
///
/// TODO(C13): 구현. 상세 요구사항은 frontend/docs/FLUTTER_FRONTEND_PLAN.md §4 참조.
class AdminNotificationScreen extends StatelessWidget {
  const AdminNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PendingScreen(
      title: '알림',
      workItem: 'C13',
      description: 'REST 로 이력을 먼저 채우고 WebSocket 으로 새 알림을 덧붙인다',
    );
  }
}
