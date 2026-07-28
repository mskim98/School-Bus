/// 토큰 보관소(포트).
///
/// 구현을 바꿀 이유가 실제로 있어서 포트로 뒀다(컨벤션 §5) —
/// 실제 구현은 플랫폼 보안 저장소를 쓰지만, 단위 테스트에서는 인메모리 구현으로 갈아끼운다.
///
/// 토큰 두 개를 문자열로만 다룬다. 해석(역할·만료 등)은 이 계층의 일이 아니다.
abstract interface class TokenStorage {
  Future<String?> readAccessToken();

  Future<String?> readRefreshToken();

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  });

  /// 로그아웃·재발급 실패 시 호출. 남은 토큰이 없어야 한다.
  Future<void> clear();
}
