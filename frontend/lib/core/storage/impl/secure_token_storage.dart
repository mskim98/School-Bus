import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../spec/token_storage.dart';

/// 플랫폼 보안 저장소 기반 구현.
///
/// 모바일은 Keychain(iOS)/Keystore(Android), 웹은 WebCrypto 로 암호화해 저장한다 —
/// 패키지가 알아서 분기하므로 호출부는 신경 쓰지 않아도 된다.
///
/// ⚠️ 웹에서는 결국 브라우저 저장소에 남는다. XSS 가 나면 토큰도 함께 털린다는 뜻이라,
/// accessToken 수명이 15분으로 짧게 잡혀 있는 게 이 위험을 줄이는 장치다.
class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    // 두 값을 항상 같이 쓴다. accessToken 만 갱신하고 refreshToken 을 두면
    // 서버의 refresh 토큰 회전과 어긋나 다음 재발급이 실패한다.
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => const SecureTokenStorage(FlutterSecureStorage()),
);
