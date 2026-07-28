import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/screen/login_screen.dart';
import '../../features/location/presentation/screen/admin_monitor_screen.dart';
import '../../features/notification/presentation/screen/admin_notification_screen.dart';
import '../../features/rideevent/presentation/screen/driver_roster_screen.dart';
import '../../features/routing/presentation/screen/admin_dispatch_screen.dart';
import '../../features/routing/presentation/screen/admin_route_list_screen.dart';
import '../../features/routing/presentation/screen/driver_route_screen.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';
import 'role_redirect.dart';

/// 앱 라우터.
///
/// 역할별 진입 분기와 접근 차단을 [RoleRedirect] 한 곳에서 처리한다 —
/// 화면마다 "권한 없으면 되돌리기"를 넣으면 반드시 어딘가 빠진다.
final routerProvider = Provider<GoRouter>((ref) {
  // 로그인/로그아웃/세션만료로 상태가 바뀌면 라우터가 redirect 를 다시 평가하게 한다.
  // 이게 없으면 로그인에 성공해도 화면이 그대로 멈춰 있다.
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return RoleRedirect.resolve(
        location: state.matchedLocation,
        session: auth.value,
        // 앱 시작 직후 저장된 토큰을 읽는 중. 아직 값이 한 번도 안 들어온 상태다.
        isRestoring: auth.isLoading && !auth.hasValue,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),

      // ── 기사 ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          // 기사는 운행 중 폰으로 쓴다 — 데스크톱에서 열어도 모바일 레이아웃을 유지한다.
          forceCompact: true,
          destinations: const [
            ShellDestination(
              label: '오늘의 노선',
              icon: Icons.map_outlined,
              selectedIcon: Icons.map,
            ),
            ShellDestination(
              label: '승하차 명단',
              icon: Icons.how_to_reg_outlined,
              selectedIcon: Icons.how_to_reg,
            ),
          ],
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.driverRoute,
                builder: (context, state) => const DriverRouteScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.driverRoster,
                builder: (context, state) => const DriverRosterScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── 관리자 ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(
          navigationShell: shell,
          destinations: const [
            ShellDestination(
              label: '관제 지도',
              icon: Icons.location_on_outlined,
              selectedIcon: Icons.location_on,
            ),
            ShellDestination(
              label: '배차',
              icon: Icons.alt_route_outlined,
              selectedIcon: Icons.alt_route,
            ),
            ShellDestination(
              label: '노선',
              icon: Icons.route_outlined,
              selectedIcon: Icons.route,
            ),
            ShellDestination(
              label: '알림',
              icon: Icons.notifications_outlined,
              selectedIcon: Icons.notifications,
            ),
          ],
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminMonitor,
                builder: (context, state) => const AdminMonitorScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminDispatch,
                builder: (context, state) => const AdminDispatchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminRoutes,
                builder: (context, state) => const AdminRouteListScreen(),
                routes: [
                  // 상세는 목록의 하위 경로 — 뒤로가기가 목록으로 돌아간다.
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => const AdminRouteListScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.adminNotifications,
                builder: (context, state) => const AdminNotificationScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// [authControllerProvider] 가 바뀔 때마다 go_router 에 알린다.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}

/// 저장된 토큰으로 세션을 복원하는 동안 잠깐 머무는 화면.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
