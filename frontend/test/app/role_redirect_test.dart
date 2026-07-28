import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/app/router/app_routes.dart';
import 'package:school_bus/app/router/role_redirect.dart';
import 'package:school_bus/shared/domain/auth_session.dart';
import 'package:school_bus/shared/domain/role.dart';

AuthSession session(Role role, {int? tenantId = 1}) => AuthSession(
  userId: 1,
  email: 'x@school.com',
  role: role,
  tenantId: tenantId,
);

/// null 이면 "지금 경로 유지".
String? go(String location, {AuthSession? as, bool restoring = false}) =>
    RoleRedirect.resolve(
      location: location,
      session: as,
      isRestoring: restoring,
    );

void main() {
  group('세션 복원 중', () {
    test('스플래시에 머문다 — 로그인 화면이 번쩍이지 않게', () {
      expect(go(AppRoutes.splash, restoring: true), isNull);
      expect(go(AppRoutes.driverRoute, restoring: true), AppRoutes.splash);
      expect(go(AppRoutes.adminMonitor, restoring: true), AppRoutes.splash);
    });
  });

  group('로그인 안 됨', () {
    test('어디를 요청해도 로그인으로 보낸다', () {
      expect(go(AppRoutes.splash), AppRoutes.login);
      expect(go(AppRoutes.driverRoute), AppRoutes.login);
      expect(go(AppRoutes.adminMonitor), AppRoutes.login);
    });

    test('이미 로그인 화면이면 그대로 둔다 — 무한 리다이렉트 방지', () {
      expect(go(AppRoutes.login), isNull);
    });
  });

  group('기사(DRIVER)', () {
    final driver = session(Role.driver);

    test('로그인·스플래시에서 기사 홈으로 보낸다', () {
      expect(go(AppRoutes.login, as: driver), AppRoutes.driverRoute);
      expect(go(AppRoutes.splash, as: driver), AppRoutes.driverRoute);
    });

    test('기사 영역 안에서는 그대로 둔다', () {
      expect(go(AppRoutes.driverRoute, as: driver), isNull);
      expect(go(AppRoutes.driverRoster, as: driver), isNull);
    });

    test('★ 관리자 영역에 직접 접근하면 기사 홈으로 되돌린다', () {
      // 주소창에 /admin/monitor 를 직접 쳐도 막혀야 한다.
      expect(go(AppRoutes.adminMonitor, as: driver), AppRoutes.driverRoute);
      expect(go(AppRoutes.adminDispatch, as: driver), AppRoutes.driverRoute);
      expect(go('/admin/routes/1', as: driver), AppRoutes.driverRoute);
    });
  });

  group('관리자', () {
    final academyAdmin = session(Role.academyAdmin);
    final platformAdmin = session(Role.platformAdmin, tenantId: null);

    test('두 관리자 역할 모두 관제 지도가 홈이다', () {
      expect(go(AppRoutes.login, as: academyAdmin), AppRoutes.adminMonitor);
      expect(go(AppRoutes.login, as: platformAdmin), AppRoutes.adminMonitor);
    });

    test('소속 학원이 없는 플랫폼 관리자도 관리자 영역에 들어간다', () {
      expect(platformAdmin.tenantId, isNull);
      expect(go(AppRoutes.adminDispatch, as: platformAdmin), isNull);
    });

    test('관리자 영역 안에서는 그대로 둔다', () {
      expect(go(AppRoutes.adminMonitor, as: academyAdmin), isNull);
      expect(go(AppRoutes.adminRoutes, as: academyAdmin), isNull);
      expect(go('/admin/routes/7', as: academyAdmin), isNull);
      expect(go(AppRoutes.adminNotifications, as: academyAdmin), isNull);
    });

    test('★ 기사 영역에 직접 접근하면 관제 지도로 되돌린다', () {
      expect(
        go(AppRoutes.driverRoute, as: academyAdmin),
        AppRoutes.adminMonitor,
      );
      expect(
        go(AppRoutes.driverRoster, as: academyAdmin),
        AppRoutes.adminMonitor,
      );
    });
  });

  group('MVP 범위 밖 역할(학생·학부모)', () {
    test('로그인 화면에 붙잡아 둔다 — 거기서 "준비 중" 안내를 띄운다', () {
      for (final role in [Role.student, Role.parent]) {
        final user = session(role);
        expect(go(AppRoutes.login, as: user), isNull, reason: role.wireName);
        expect(go(AppRoutes.driverRoute, as: user), AppRoutes.login);
        expect(go(AppRoutes.adminMonitor, as: user), AppRoutes.login);
      }
    });
  });

  group('homeOf', () {
    test('역할별 첫 화면', () {
      expect(RoleRedirect.homeOf(Role.driver), AppRoutes.driverRoute);
      expect(RoleRedirect.homeOf(Role.academyAdmin), AppRoutes.adminMonitor);
      expect(RoleRedirect.homeOf(Role.platformAdmin), AppRoutes.adminMonitor);
    });
  });

  group('경로 상수', () {
    test('노선 상세 경로를 만든다', () {
      expect(AppRoutes.adminRouteDetailOf(12), '/admin/routes/12');
    });
  });
}
