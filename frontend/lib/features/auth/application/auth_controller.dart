import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/auth_session.dart';
import '../data/auth_repository.dart';

/// 로그인 세션 상태.
///
/// 값이 null 이면 "로그인 안 됨"이다. 라우터(C5)가 이 값을 보고 진입 화면을 정한다.
class AuthController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// 앱 시작 시 저장된 토큰으로 세션을 복원한다.
  /// 실패해도 예외를 내지 않는다 — "로그인 안 된 상태"일 뿐이다.
  @override
  Future<AuthSession?> build() => _repository.restore();

  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue.loading();
    // guard 가 예외를 AsyncError 로 담아준다 — 화면은 state.error 를 읽어 표시한다.
    state = await AsyncValue.guard(
      () => _repository.login(email: email, password: password),
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }

  /// [AuthInterceptor] 가 401 을 받았을 때 호출한다.
  /// 성공하면 새 세션으로 상태를 갱신하고 true 를 돌려준다.
  Future<bool> refreshTokens() async {
    final session = await _repository.refresh();
    if (session == null) return false;
    // 재발급으로는 busId 가 다시 오지 않으므로 기존 값을 잃지 않게 이어붙인다.
    state = AsyncValue.data(session.copyWith(busId: state.value?.busId));
    return true;
  }

  /// 재발급까지 실패해 세션이 끊긴 경우. 라우터가 로그인 화면으로 되돌린다.
  void onSessionExpired() {
    state = const AsyncValue.data(null);
  }

  /// 기사 로그인 후 `GET /api/buses/me` 로 얻은 담당 버스를 세션에 얹는다(C6).
  void attachBusId(int busId) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(busId: busId));
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// 현재 로그인 사용자. 로딩·에러 중에는 null 이다.
final currentSessionProvider = Provider<AuthSession?>(
  (ref) => ref.watch(authControllerProvider).value,
);
