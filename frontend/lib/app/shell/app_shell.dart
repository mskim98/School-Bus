import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../theme/app_spacing.dart';

/// 셸 탭 하나.
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// 기사·관리자가 공유하는 반응형 셸.
///
/// 폭에 따라 탐색 UI 를 바꾼다 — 한 코드베이스로 모바일(기사)과 데스크톱(관제)을
/// 모두 그려야 하기 때문이다(계획서 §1.2).
///  - 좁은 화면: 하단 [NavigationBar]  — 엄지로 닿는 위치
///  - 넓은 화면: 좌측 [NavigationRail] — 지도에 가로 폭을 최대한 내준다
///
/// 분기 기준은 [AppBreakpoints] 한 곳에 둔다. 화면마다 다른 숫자를 쓰면 레이아웃이 어긋난다.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  });

  /// go_router 의 [StatefulShellRoute] 가 넘겨주는 브랜치 상태.
  /// 탭을 옮겨도 각 탭의 스크롤 위치·입력값이 유지된다.
  final StatefulNavigationShell navigationShell;
  final List<ShellDestination> destinations;

  void _onSelect(int index) {
    // 이미 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 되돌린다(흔한 기대 동작).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.compact;
    final current = navigationShell.currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(destinations[current].label),
        actions: const [_AccountButton()],
      ),
      body: isWide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: current,
                  onDestinationSelected: _onSelect,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            )
          : navigationShell,
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: current,
              onDestinationSelected: _onSelect,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}

/// 로그인 정보 확인 + 로그아웃.
class _AccountButton extends ConsumerWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const SizedBox.shrink();

    return PopupMenuButton<void>(
      tooltip: '계정',
      icon: const Icon(Icons.account_circle_outlined),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.role.label),
              const SizedBox(height: AppSpacing.xs / 2),
              Text(session.email, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: () => ref.read(authControllerProvider.notifier).logout(),
          child: const Row(
            children: [
              Icon(Icons.logout, size: 18),
              SizedBox(width: AppSpacing.sm),
              Text('로그아웃'),
            ],
          ),
        ),
      ],
    );
  }
}
