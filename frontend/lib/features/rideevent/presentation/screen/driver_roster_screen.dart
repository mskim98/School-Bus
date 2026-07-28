import 'package:flutter/material.dart';

import '../../../../core/ui/pending_screen.dart';

/// 승하차 명단 — POST /api/ride-events 로 승차·하차·인계를 기록하고 그날 명단을 조회한다
///
/// TODO(C7): 구현. 상세 요구사항은 frontend/docs/FLUTTER_FRONTEND_PLAN.md §4 참조.
class DriverRosterScreen extends StatelessWidget {
  const DriverRosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PendingScreen(
      title: '승하차 명단',
      workItem: 'C7',
      description: 'POST /api/ride-events 로 승차·하차·인계를 기록하고 그날 명단을 조회한다',
    );
  }
}
