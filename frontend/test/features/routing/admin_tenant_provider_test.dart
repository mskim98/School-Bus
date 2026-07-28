import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/auth/application/auth_controller.dart';
import 'package:school_bus/features/routing/application/admin_tenant_provider.dart';
import 'package:school_bus/shared/domain/auth_session.dart';
import 'package:school_bus/shared/domain/role.dart';

AdminTenant? tenantFor(AuthSession? session) {
  final container = ProviderContainer(
    overrides: [currentSessionProvider.overrideWithValue(session)],
  );
  addTearDown(container.dispose);
  return container.read(adminTenantProvider);
}

AuthSession sessionOf(Role role, {int? tenantId}) =>
    AuthSession(userId: 1, email: 'a@b.c', role: role, tenantId: tenantId);

void main() {
  test('학원 관리자는 세션의 tenantId 를 쓴다 — 고정값 표시 없음', () {
    final tenant = tenantFor(sessionOf(Role.academyAdmin, tenantId: 7));

    expect(tenant?.id, 7);
    expect(tenant?.isFixedFallback, isFalse);
  });

  test('★ 플랫폼 관리자는 소속이 없어 고정값으로 떨어진다 — 화면이 "고정값"을 표시해야 한다', () {
    // JWT 클레임이 ":PLATFORM_ADMIN" 이라 tenantId 자리가 비어 있다(계획서 §3.4).
    final tenant = tenantFor(sessionOf(Role.platformAdmin));

    expect(tenant?.id, platformAdminFallbackTenantId);
    expect(tenant?.isFixedFallback, isTrue);
  });

  test('로그인 전이면 null', () {
    expect(tenantFor(null), isNull);
  });

  test('관리자가 아닌 역할은 null — 배차·노선 화면 자체가 대상이 아니다', () {
    expect(tenantFor(sessionOf(Role.driver)), isNull);
    expect(tenantFor(sessionOf(Role.student, tenantId: 1)), isNull);
  });
}
