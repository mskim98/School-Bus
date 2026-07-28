import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// ⚠️ `bootstrap()` 에서 override 해야 하는 provider.
///
/// **provider 선언이 구현체 파일이 아니라 여기 있는 이유**(컨벤션 §5) —
/// 구현체 파일에 두면 소비자가 `impl/...` 을 import 하게 되고, 그러면 구현을 갈아끼울 때
/// 호출부를 전부 고쳐야 한다. 포트를 만든 목적 자체가 사라진다.
/// 배선은 합성 지점 한 곳(`bootstrap()`)에만 둔다.
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => throw UnimplementedError(
    'tokenStorageProvider 를 bootstrap() 에서 override 해야 합니다',
  ),
);
