import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/spec/session_refresher.dart';
import 'auth_controller.dart';

/// [SessionRefresher] 포트의 구현. core 의 `AuthInterceptor` 가 이걸 통해
/// 재발급을 요청한다 — core 는 이 클래스의 존재를 모른다(DIP).
///
/// `bootstrap()` 에서 `sessionRefresherProvider` 를 이 구현으로 override 한다.
class AuthSessionRefresher implements SessionRefresher {
  const AuthSessionRefresher(this._ref);

  final Ref _ref;

  @override
  Future<bool> refresh() =>
      _ref.read(authControllerProvider.notifier).refreshTokens();

  @override
  void onSessionExpired() =>
      _ref.read(authControllerProvider.notifier).onSessionExpired();
}
