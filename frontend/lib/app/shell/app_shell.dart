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
    this.forceCompact = false,
  });

  /// go_router 의 [StatefulShellRoute] 가 넘겨주는 브랜치 상태.
  /// 탭을 옮겨도 각 탭의 스크롤 위치·입력값이 유지된다.
  final StatefulNavigationShell navigationShell;
  final List<ShellDestination> destinations;

  /// 화면 폭과 무관하게 모바일 레이아웃을 강제한다.
  ///
  /// **기사 화면이 이걸 켠다.** 기사는 운행 중 폰으로 쓰는 게 전제라, 데스크톱
  /// 브라우저에서 열었다고 관제용 넓은 레이아웃을 보여주면 실제와 다른 화면을
  /// 검증하게 된다. 넓은 화면에서는 폰 폭으로 가운데 정렬해 보여준다.
  final bool forceCompact;

  void _onSelect(int index) {
    // 이미 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 되돌린다(흔한 기대 동작).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = !forceCompact && screenWidth >= AppBreakpoints.compact;
    final current = navigationShell.currentIndex;

    // 기사 화면을 넓은 모니터에서 열면 폰 폭으로 좁혀 가운데 둔다 —
    // 실제 사용 환경과 같은 비율로 확인하기 위함이다.
    final needsPhoneFrame =
        forceCompact && screenWidth >= AppBreakpoints.compact;

    final scaffold = Scaffold(
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

    if (!needsPhoneFrame) return scaffold;

    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.compact),
          // 테두리를 둘러 "이건 폰 화면"이라고 알린다 — 모니터에서 볼 때
          // 가운데 정렬만 하면 그냥 좁은 웹페이지로 읽힌다.
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(
                vertical: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            // MediaQuery 를 좁혀서 넘겨준다 — 안쪽 화면이 자기 폭을 물어봤을 때
            // 모니터 폭이 아니라 프레임 폭을 보게 해야 반응형 분기가 실제와 맞는다.
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(
                    AppBreakpoints.compact,
                    MediaQuery.sizeOf(context).height,
                  ),
                ),
                child: scaffold,
              ),
            ),
          ),
        ),
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
