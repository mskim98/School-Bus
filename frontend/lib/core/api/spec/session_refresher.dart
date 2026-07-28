import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 토큰 재발급 포트.
///
/// `AuthInterceptor`(core)는 401 을 받으면 재발급을 시도해야 하는데, 그 구현은
/// `features/auth` 에 있다. **core 가 features 를 import 하면 의존 방향이 뒤집히므로**
/// (컨벤션 C-1) core 는 이 인터페이스만 알고, 구현은 features 쪽에서 주입한다 — DIP.
///
/// 구현체는 `bootstrap()` 에서 [sessionRefresherProvider] 를 override 해 등록한다.
abstract interface class SessionRefresher {
  /// refreshToken 으로 재발급을 시도한다. 성공하면 true.
  Future<bool> refresh();

  /// 재발급까지 실패해 세션이 끊긴 경우. 로그인 화면으로 되돌리는 신호다.
  void onSessionExpired();
}

/// ⚠️ 반드시 override 해야 하는 provider.
///
/// 기본 구현을 두지 않고 던지는 이유 — 조용히 동작하는 no-op 을 두면 재발급이
/// 안 되는 걸 아무도 모른 채 401 만 계속 나게 된다. 배선 누락은 즉시 드러나는 게 낫다.
final sessionRefresherProvider = Provider<SessionRefresher>(
  (ref) => throw UnimplementedError(
    'sessionRefresherProvider 를 bootstrap() 에서 override 해야 합니다',
  ),
);
