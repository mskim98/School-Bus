import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_response.dart';
import '../../../core/storage/spec/token_storage.dart';
import '../../../shared/domain/auth_session.dart';
import 'dto/token_pair_dto.dart';
import 'jwt_decoder.dart';

/// 인증 API + 토큰 보관.
///
/// 서버가 하나뿐이고 교체 계획이 없어 포트로 나누지 않는다(컨벤션 §5).
class AuthRepository {
  const AuthRepository(this._client, this._storage);

  final ApiClient _client;
  final TokenStorage _storage;

  /// 로그인 → 토큰 저장 → 세션 복원까지 한 번에.
  ///
  /// 실패는 [ApiException] 으로 올라간다(401 = 이메일/비밀번호 불일치).
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final tokens = await _client.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
      decode: Decode.one(TokenPairDto.fromJson),
    );
    return _persist(tokens);
  }

  /// 저장된 refreshToken 으로 재발급. 토큰이 없거나 서버가 거절하면 null.
  ///
  /// null 을 돌려주는 이유 — 이건 "예외 상황"이 아니라 **정상적인 세션 만료**다.
  /// 호출부(인터셉터)는 실패 시 조용히 로그인 화면으로 보내야 하므로 예외보다 다루기 쉽다.
  Future<AuthSession?> refresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return null;

    try {
      final tokens = await _client.post(
        '/api/auth/refresh',
        body: {'refreshToken': refreshToken},
        decode: Decode.one(TokenPairDto.fromJson),
      );
      return _persist(tokens);
    } on Object {
      // 만료·서명 불일치·유저 삭제 — 어느 쪽이든 되살릴 방법이 없다.
      await _storage.clear();
      return null;
    }
  }

  /// 앱 시작 시 저장된 토큰으로 세션 복원. 없거나 깨졌으면 null.
  ///
  /// accessToken 만 읽고 만료 여부는 보지 않는다 — 만료됐다면 첫 요청이 401 을 받고
  /// 인터셉터가 재발급하므로, 여기서 미리 검사하면 같은 판단이 두 군데로 갈라진다.
  Future<AuthSession?> restore() async {
    return JwtDecoder.toSession(await _storage.readAccessToken());
  }

  /// 기사의 담당 busId. 담당 버스가 없으면(404) null.
  ///
  /// `/api/buses` 가 아니라 여기(auth)에 두는 이유 — 이건 버스 관리 기능이 아니라
  /// **세션을 완성하는 단계**다(`MVP_API_SPEC.md` §2.3 "세션 부트스트랩").
  /// 기사용 API 가 전부 busId 를 요구하는데 토큰에는 없어서, 로그인 직후 1회 받아
  /// 세션에 얹는다. bus 를 별도 feature 로 빼면 auth 가 그걸 import 해야 해서
  /// feature 간 의존이 생긴다(컨벤션 C-1).
  Future<int?> fetchMyBusId() async {
    try {
      return await _client.get(
        '/api/buses/me',
        decode: (data) => (data! as Map<String, dynamic>)['id'] as int,
      );
    } on ApiException catch (e) {
      // 아직 배차되지 않은 기사 — 오류가 아니라 "버스 없음" 상태다.
      if (e.kind == ApiErrorKind.notFound) return null;
      rethrow;
    }
  }

  Future<void> logout() => _storage.clear();

  Future<AuthSession> _persist(TokenPairDto tokens) async {
    await _storage.save(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    final session = JwtDecoder.toSession(tokens.accessToken);
    if (session == null) {
      // 서버가 준 토큰을 우리가 못 읽는 상황 — 계약이 어긋난 것이므로 조용히 넘기지 않는다.
      await _storage.clear();
      throw StateError('로그인 응답의 토큰을 해석할 수 없습니다');
    }
    return session;
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  ),
);
