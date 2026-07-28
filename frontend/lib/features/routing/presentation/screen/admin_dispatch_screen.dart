import 'package:flutter/material.dart';

import '../../../../core/ui/pending_screen.dart';

/// 배차 — auto-assign 으로 배차를 제안받아 검토한 뒤 confirm 으로 확정한다
///
/// TODO(C10): 구현. 상세 요구사항은 frontend/docs/FLUTTER_FRONTEND_PLAN.md §4 참조.
class AdminDispatchScreen extends StatelessWidget {
  const AdminDispatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PendingScreen(
      title: '배차',
      workItem: 'C10',
      description: 'auto-assign 으로 배차를 제안받아 검토한 뒤 confirm 으로 확정한다',
    );
  }
}
