import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/auth/data/jwt_decoder.dart';
import 'package:school_bus/shared/domain/role.dart';

/// 서명 없는 가짜 JWT — 클라이언트는 서명을 검증하지 않으므로 payload 만 맞으면 된다.
String fakeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(payload)}.signature';
}

void main() {
  group('JwtDecoder.toSession', () {
    test('학원 관리자 토큰에서 역할과 소속 학원을 읽는다', () {
      final session = JwtDecoder.toSession(
        fakeJwt({
          'sub': '4',
          'email': 'admin@school.com',
          'memberships': ['1:ACADEMY_ADMIN'],
          'type': 'access',
        }),
      );

      expect(session, isNotNull);
      expect(session!.userId, 4);
      expect(session.email, 'admin@school.com');
      expect(session.role, Role.academyAdmin);
      expect(session.tenantId, 1);
    });

    test('플랫폼 관리자는 tenantId 자리가 비어 있고 null 로 해석된다', () {
      // ⚠️ ":PLATFORM_ADMIN" — 앞자리가 빈 문자열이다. int.parse 하면 터지는 지점.
      final session = JwtDecoder.toSession(
        fakeJwt({
          'sub': '5',
          'email': 'platform@school.com',
          'memberships': [':PLATFORM_ADMIN'],
        }),
      );

      expect(session!.role, Role.platformAdmin);
      expect(session.tenantId, isNull);
    });

    test('기사 토큰을 읽는다 — busId 는 토큰에 없으므로 null 이다', () {
      final session = JwtDecoder.toSession(
        fakeJwt({
          'sub': '3',
          'email': 'driver@school.com',
          'memberships': ['1:DRIVER'],
        }),
      );

      expect(session!.role, Role.driver);
      expect(
        session.busId,
        isNull,
        reason: 'busId 는 GET /api/buses/me 로 따로 채운다',
      );
    });

    test('멤버십이 여럿이면 화면이 있는 역할을 고른다', () {
      final session = JwtDecoder.toSession(
        fakeJwt({
          'sub': '9',
          'email': 'both@school.com',
          'memberships': ['1:PARENT', '1:DRIVER'],
        }),
      );

      expect(session!.role, Role.driver);
    });

    test('지원 역할이 없으면 그중 하나를 돌려준다 — 로그인 화면이 안내를 띄운다', () {
      final session = JwtDecoder.toSession(
        fakeJwt({
          'sub': '1',
          'email': 'student@school.com',
          'memberships': ['1:STUDENT'],
        }),
      );

      expect(session!.role, Role.student);
      expect(session.role.isSupportedInMvp, isFalse);
    });

    test('알 수 없는 역할이 섞여 있어도 죽지 않는다', () {
      final session = JwtDecoder.toSession(
        fakeJwt({
          'sub': '7',
          'email': 'x@school.com',
          'memberships': ['1:FUTURE_ROLE', '1:DRIVER'],
        }),
      );

      expect(session!.role, Role.driver);
    });

    test('깨진 토큰·null·빈 멤버십은 전부 null 이다', () {
      expect(JwtDecoder.toSession(null), isNull);
      expect(JwtDecoder.toSession(''), isNull);
      expect(JwtDecoder.toSession('not-a-jwt'), isNull);
      expect(JwtDecoder.toSession('a.b.c'), isNull);
      expect(
        JwtDecoder.toSession(fakeJwt({'sub': '1', 'memberships': []})),
        isNull,
      );
      expect(
        JwtDecoder.toSession(
          fakeJwt({
            'email': 'x',
            'memberships': ['1:DRIVER'],
          }),
        ),
        isNull,
        reason: 'sub 가 없으면 사용자를 특정할 수 없다',
      );
    });

    test('padding 이 필요한 payload 도 디코딩된다', () {
      // base64url 은 길이에 따라 '=' padding 이 필요한데 JWT 는 그걸 떼고 보낸다.
      // normalize 를 안 하면 여기서 FormatException 이 난다.
      final session = JwtDecoder.toSession(
        fakeJwt({
          'sub': '3',
          'email': 'padding-test-user@school.com',
          'memberships': ['1:DRIVER'],
        }),
      );

      expect(session, isNotNull);
    });
  });

  group('Role', () {
    test('MVP 지원 역할은 기사와 관리자뿐이다', () {
      expect(Role.driver.isSupportedInMvp, isTrue);
      expect(Role.academyAdmin.isSupportedInMvp, isTrue);
      expect(Role.platformAdmin.isSupportedInMvp, isTrue);
      expect(Role.student.isSupportedInMvp, isFalse);
      expect(Role.parent.isSupportedInMvp, isFalse);
    });

    test('isAdmin 은 관리자 두 역할만 참이다', () {
      expect(Role.academyAdmin.isAdmin, isTrue);
      expect(Role.platformAdmin.isAdmin, isTrue);
      expect(Role.driver.isAdmin, isFalse);
    });

    test('모르는 문자열은 null — 서버에 역할이 추가돼도 앱이 죽지 않는다', () {
      expect(Role.fromWire('NEW_ROLE'), isNull);
      expect(Role.fromWire(null), isNull);
      expect(Role.fromWire('DRIVER'), Role.driver);
    });
  });
}
