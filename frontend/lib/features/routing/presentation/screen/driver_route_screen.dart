import 'package:flutter/material.dart';

import '../../../../core/ui/pending_screen.dart';

/// 오늘의 노선 — GET /api/route-plans/driver/{busId} — 정차 순서와 노선 polyline 을 지도에 그린다
///
/// TODO(C6): 구현. 상세 요구사항은 frontend/docs/FLUTTER_FRONTEND_PLAN.md §4 참조.
class DriverRouteScreen extends StatelessWidget {
  const DriverRouteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PendingScreen(
      title: '오늘의 노선',
      workItem: 'C6',
      description:
          'GET /api/route-plans/driver/{busId} — 정차 순서와 노선 polyline 을 지도에 그린다',
    );
  }
}
