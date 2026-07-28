/// 앱의 모든 경로. **문자열 리터럴을 화면에 직접 쓰지 않는다**(컨벤션 §8, 검사 C-4).
///
/// 경로를 여기 모아두면 이름을 바꿀 때 컴파일러가 빠진 곳을 잡아준다.
/// 화면에 흩뿌려두면 오타가 런타임에야 404 로 드러난다.
class AppRoutes {
  const AppRoutes._();

  /// 저장된 토큰을 읽어 세션을 복원하는 동안 머무는 곳.
  /// 복원이 끝나면 [login] 또는 역할별 홈으로 자동 이동한다.
  static const splash = '/';

  static const login = '/login';

  // ── 기사(DRIVER) ──
  static const driverRoute = '/driver/route';
  static const driverRoster = '/driver/roster';

  // ── 관리자(ACADEMY_ADMIN · PLATFORM_ADMIN) ──
  static const adminMonitor = '/admin/monitor';
  static const adminDispatch = '/admin/dispatch';
  static const adminRoutes = '/admin/routes';
  static const adminNotifications = '/admin/notifications';

  /// 노선 상세 — `:id` 를 채워 쓴다.
  static const adminRouteDetail = '/admin/routes/:id';

  static String adminRouteDetailOf(int planId) => '/admin/routes/$planId';
}
