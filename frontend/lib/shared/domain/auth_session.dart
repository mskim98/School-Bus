import 'role.dart';

/// 로그인한 사용자. **accessToken(JWT) 을 해석해 만든다.**
///
/// 백엔드에 `/api/users/me` 같은 엔드포인트가 없고 로그인 응답도 토큰 두 개뿐이라,
/// 역할·userId·소속 학원은 토큰 payload 에서 꺼내는 수밖에 없다
/// (MVP_API_SPEC §2 · 계획서 §3.4).
///
/// 서명 검증은 하지 않는다 — 서버가 매 요청 검증하므로 클라이언트는 화면 분기용으로만 읽는다.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.role,
    this.tenantId,
    this.busId,
  });

  final int userId;
  final String email;
  final Role role;

  /// 소속 학원. **`PLATFORM_ADMIN` 은 소속이 없어 null 이다** —
  /// 토큰 클레임도 `":PLATFORM_ADMIN"` 처럼 앞자리가 빈 문자열로 온다.
  final int? tenantId;

  /// 기사의 담당 버스 id.
  ///
  /// 토큰에는 없다 — 로그인 직후 `GET /api/buses/me` 로 따로 채운다(계획서 §3.5).
  /// 기사용 API 가 전부 busId 를 요구하므로 세션에 얹어 화면마다 다시 조회하지 않게 한다.
  final int? busId;

  AuthSession copyWith({int? busId}) => AuthSession(
    userId: userId,
    email: email,
    role: role,
    tenantId: tenantId,
    busId: busId ?? this.busId,
  );

  @override
  String toString() =>
      'AuthSession(userId: $userId, role: ${role.wireName}, tenantId: $tenantId, busId: $busId)';
}
