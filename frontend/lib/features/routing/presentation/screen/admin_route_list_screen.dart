import 'package:flutter/material.dart';

import '../../../../core/ui/pending_screen.dart';

/// 노선 — GET /api/route-plans 목록과 상세(정차 순서·지도)를 본다
///
/// TODO(C11): 구현. 상세 요구사항은 frontend/docs/FLUTTER_FRONTEND_PLAN.md §4 참조.
class AdminRouteListScreen extends StatelessWidget {
  const AdminRouteListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PendingScreen(
      title: '노선',
      workItem: 'C11',
      description: 'GET /api/route-plans 목록과 상세(정차 순서·지도)를 본다',
    );
  }
}
