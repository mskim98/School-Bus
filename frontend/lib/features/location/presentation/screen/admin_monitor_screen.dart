import 'package:flutter/material.dart';

import '../../../../core/ui/pending_screen.dart';

/// 관제 지도 — GET /api/locations/buses 를 3초마다 폴링해 버스 위치를 지도에 표시한다
///
/// TODO(C9): 구현. 상세 요구사항은 frontend/docs/FLUTTER_FRONTEND_PLAN.md §4 참조.
class AdminMonitorScreen extends StatelessWidget {
  const AdminMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PendingScreen(
      title: '관제 지도',
      workItem: 'C9',
      description: 'GET /api/locations/buses 를 3초마다 폴링해 버스 위치를 지도에 표시한다',
    );
  }
}
