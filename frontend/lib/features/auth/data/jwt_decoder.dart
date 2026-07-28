import 'dart:convert';

import '../../../shared/domain/auth_session.dart';
import '../../../shared/domain/role.dart';

/// accessToken(JWT) payload → [AuthSession].
///
/// 백엔드에 사용자 정보 API 가 없어서 토큰을 직접 읽는다(계획서 §3.4).
/// 파싱은 **repository 계층에서만** 한다 — application·presentation 은 이 파일을 모른다(컨벤션 §4).
///
/// 백엔드가 싣는 클레임(`JwtTokenProvider` 대조, 2026-07-28):
/// | `sub` | userId |
/// | `email` | 이메일 |
/// | `memberships` | `"tenantId:ROLE"` 문자열 배열 |
/// | `type` | `access` / `refresh` |
class JwtDecoder {
  const JwtDecoder._();

  /// 해석에 실패하면 null. 토큰이 깨졌을 때 앱이 죽는 대신 "로그인 필요" 로 흐르게 한다.
  static AuthSession? toSession(String? accessToken) {
    final claims = payloadOf(accessToken);
    if (claims == null) return null;

    final userId = int.tryParse('${claims['sub']}');
    if (userId == null) return null;

    final membership = _firstSupportedMembership(claims['memberships']);
    if (membership == null) return null;

    return AuthSession(
      userId: userId,
      email: claims['email'] as String? ?? '',
      role: membership.role,
      tenantId: membership.tenantId,
    );
  }

  /// JWT payload 를 Map 으로. 서명은 검증하지 않는다(서버가 한다).
  static Map<String, dynamic>? payloadOf(String? token) {
    if (token == null || token.isEmpty) return null;

    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      // JWT 는 padding 없는 base64url 이라 normalize 로 '=' 를 채워야 디코딩된다.
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(decoded);
      return json is Map<String, dynamic> ? json : null;
    } on FormatException {
      return null;
    }
  }

  /// 멤버십 목록에서 MVP 가 지원하는 역할을 고른다.
  ///
  /// 한 계정이 여러 멤버십을 가질 수 있어서(예: 학부모이면서 기사) 앞에서부터 훑되,
  /// 화면이 있는 역할(기사·관리자)을 우선 고른다 — 지원하지 않는 역할만 있으면
  /// 그중 첫 번째를 돌려주고, 로그인 단계에서 "지원하지 않는 역할" 로 안내한다.
  static _Membership? _firstSupportedMembership(Object? raw) {
    if (raw is! List) return null;

    _Membership? fallback;
    for (final entry in raw) {
      final parsed = _parseMembership(entry);
      if (parsed == null) continue;
      if (parsed.role.isSupportedInMvp) return parsed;
      fallback ??= parsed;
    }
    return fallback;
  }

  /// `"1:ACADEMY_ADMIN"` → (tenantId: 1, role: academyAdmin)
  /// `":PLATFORM_ADMIN"` → (tenantId: null, role: platformAdmin)
  static _Membership? _parseMembership(Object? entry) {
    if (entry is! String) return null;

    final separator = entry.indexOf(':');
    if (separator < 0) return null;

    final tenantPart = entry.substring(0, separator);
    final role = Role.fromWire(entry.substring(separator + 1));
    if (role == null) return null;

    // ⚠️ 플랫폼 관리자는 앞자리가 빈 문자열이다. 그대로 int.parse 하면 터진다.
    return _Membership(
      tenantId: tenantPart.isEmpty ? null : int.tryParse(tenantPart),
      role: role,
    );
  }
}

class _Membership {
  const _Membership({required this.role, this.tenantId});
  final Role role;
  final int? tenantId;
}
