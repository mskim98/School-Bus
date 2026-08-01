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
    this.subtitle,
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

  /// 앱바 제목 아래에 붙일 한 줄. null 이면 지금까지처럼 제목만 나온다.
  ///
  /// **기사 셸만 준다.** 기사는 "어느 차로 어느 편을" 몰고 있는지가 화면을
  /// 옮겨 다녀도 계속 보여야 하는데, 관리자는 여러 버스를 동시에 보므로 그런
  /// 고정된 맥락이 없다. 셸은 자리와 글자 크기만 정하고 **무엇을 쓸지는 넘겨받는다**
  /// — 셸이 버스를 알면 `app/` 이 feature 를 아는 게 된다(컨벤션 §2).
  final Widget? subtitle;

  void _onSelect(int index) {
    // 이미 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 되돌린다(흔한 기대 동작).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// 앱바 높이. 부제가 없으면 M3 기본값 그대로다.
  ///
  /// ⚠️ 기본 56 은 **제목 한 줄** 기준이라, 부제를 더한 2줄은 글자 배율 **1.3배부터
  /// 앱바 밖으로 넘친다**(2026-07-29 위젯 테스트 실측: 제목 top −4.5 · 부제
  /// bottom 60.5 / 앱바 0~56). 오버플로 예외가 안 떠서 눈에 안 띄지만 실제로는
  /// 제목이 상태바로 파고들고 부제가 본문 첫 줄과 겹친다.
  ///
  /// 부제는 `3호차 · 하원 A노선` 처럼 **지금 어느 차의 어느 편인지**를 말하는 값이라
  /// 잘리면 안 된다. 운전석에서 배율을 키워 쓰는 기사가 실제로 많다.
  ///
  /// 1.34 로 묶는 이유: M3 가 앱바 텍스트 배율을 그 값에서 클램프해 글자가 더 커지지
  /// 않는다. 높이만 더 늘리면 빈 공간만 생긴다.
  double _toolbarHeight(BuildContext context) {
    if (subtitle == null) return kToolbarHeight;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.34);
    return kToolbarHeight * scale;
  }

  /// 앱바 제목. [subtitle] 이 없으면 지금까지와 똑같이 한 줄짜리 제목이다.
  ///
  /// 두 줄 모두 `maxLines: 1` 로 자른다 — 노선명이 길다고 줄바꿈되면 높이를 키워도
  /// 결국 넘친다. 높이는 [_toolbarHeight] 가 배율에 맞춰 늘린다.
  Widget _title(BuildContext context, String label) {
    final subtitle = this.subtitle;
    if (subtitle == null) return Text(label);

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 스타일을 지정하지 않는다 — `AppBarTheme.titleTextStyle` 을 그대로 물려받아
        // 부제가 붙었다고 제목 크기가 달라지지 않게 한다.
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        // 부제의 크기·색은 **셸이 정한다.** 넘겨받은 위젯이 스타일까지 고르면
        // 부제를 다는 셸이 늘어날 때마다 모양이 갈라진다.
        DefaultTextStyle.merge(
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
          ),
          child: subtitle,
        ),
      ],
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
        toolbarHeight: _toolbarHeight(context),
        title: _title(context, destinations[current].label),
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
