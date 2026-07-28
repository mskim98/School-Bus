/// `POST /api/auth/login` · `POST /api/auth/refresh` 의 응답 `data`.
///
/// ⚠️ refresh 응답도 **두 값을 모두 새로 준다**(refreshToken 회전) —
/// accessToken 만 갈아끼우면 다음 재발급이 실패한다(MVP_API_SPEC §2.2).
class TokenPairDto {
  const TokenPairDto({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  static TokenPairDto fromJson(Map<String, dynamic> json) => TokenPairDto(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
  );
}
