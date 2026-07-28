import '../../shared/domain/auth_session.dart';
import '../../shared/domain/role.dart';
import 'app_routes.dart';

/// 역할·로그인 상태에 따라 갈 곳을 정한다.
///
/// 판단 로직을 위젯이 아니라 이 순수 함수에 모은 이유:
///  - 화면 여러 곳에 흩어지면 "어떤 경우에 어디로 가는지"를 아무도 전체로 못 본다
///  - 순수 함수라 위젯 없이 단위 테스트로 전 경우를 고정할 수 있다
///
/// 반환값이 null 이면 "지금 경로 그대로 둔다"는 뜻이다(go_router 규약).
class RoleRedirect {
  const RoleRedirect._();

  /// [isRestoring] — 앱 시작 직후 저장된 토큰을 읽는 중.
  /// 이때 세션이 없다고 로그인으로 보내면, 이미 로그인한 사용자에게도
  /// 로그인 화면이 한 번 번쩍이고 사라진다.
  static String? resolve({
    required String location,
    required AuthSession? session,
    required bool isRestoring,
  }) {
    if (isRestoring) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final isOnLogin = location == AppRoutes.login;

    // 로그인 안 됨 → 로그인 화면
    if (session == null) {
      return isOnLogin ? null : AppRoutes.login;
    }

    // 로그인은 됐지만 MVP 에 화면이 없는 역할(학생·학부모).
    // 로그인 화면에 머물게 하고, 거기서 "준비 중" 안내를 보여준다.
    if (!session.role.isSupportedInMvp) {
      return isOnLogin ? null : AppRoutes.login;
    }

    final home = homeOf(session.role);

    // 이미 로그인했는데 로그인·스플래시에 있으면 자기 홈으로
    if (isOnLogin || location == AppRoutes.splash) return home;

    // 역할에 맞지 않는 영역에 들어오면 자기 홈으로 되돌린다.
    // (기사가 주소창에 /admin/monitor 를 직접 쳐도 막힌다)
    if (!_canAccess(location: location, role: session.role)) return home;

    return null;
  }

  /// 역할별 첫 화면.
  static String homeOf(Role role) =>
      role.isAdmin ? AppRoutes.adminMonitor : AppRoutes.driverRoute;

  static bool _canAccess({required String location, required Role role}) {
    if (location.startsWith('/admin')) return role.isAdmin;
    if (location.startsWith('/driver')) return role == Role.driver;
    return true;
  }
}
