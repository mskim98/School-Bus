// ignore_for_file: prefer_initializing_formals
//
// 린트는 `this._storage` 를 쓰라고 제안하지만 Dart 는 **명명 매개변수를 private 으로
// 만들 수 없어서**(`{required this._storage}` 는 컴파일 에러) 이 규칙을 만족시킬 방법이 없다.
// 호출부 가독성을 위해 명명 매개변수를 유지하고 규칙만 끈다.

import 'package:dio/dio.dart';

import '../../storage/spec/token_storage.dart';
import '../api_config.dart';

/// Bearer 토큰 부착 + 401 자동 재발급.
///
/// accessToken 수명이 **15분**이라 앱을 쓰는 도중 반드시 만료된다. 화면마다 401 을
/// 처리하면 누락이 생기므로 여기 한 곳에서 끝낸다(계획서 §3.3).
///
/// 흐름:
///  1. 요청 나갈 때 저장된 accessToken 을 `Authorization` 헤더에 붙인다
///  2. 401 이 오면 refreshToken 으로 재발급을 **한 번만** 시도한다
///  3. 성공하면 새 토큰으로 원 요청을 1회 재시도한다
///  4. 실패하면 [onSessionExpired] 를 부르고 원래 401 을 그대로 올려보낸다
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage storage,
    required Future<bool> Function() refreshTokens,
    required void Function() onSessionExpired,
    Dio? retryDio,
  }) : _storage = storage,
       _refreshTokens = refreshTokens,
       _onSessionExpired = onSessionExpired,
       // 재시도 전용 Dio — **인터셉터를 달지 않는다.** 달면 재시도가 다시 이 인터셉터를 타고
       // 401 → refresh → 재시도 … 로 돌 수 있다.
       //
       // [retryDio] 를 주입받는 이유: 기본값은 새 Dio 라서 테스트의 가짜 어댑터를 타지 못하고
       // 실제 네트워크로 나가버린다. 테스트는 같은 어댑터를 물린 Dio 를 넣어 재시도까지 검증한다.
       _retryDio = retryDio ?? Dio(_retryOptions);

  final TokenStorage _storage;
  final Future<bool> Function() _refreshTokens;
  final void Function() _onSessionExpired;
  final Dio _retryDio;

  /// 재시도 Dio 의 기본 설정 — 본 요청과 같은 타임아웃을 써야 동작이 갈리지 않는다.
  static final BaseOptions _retryOptions = BaseOptions(
    baseUrl: ApiConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  );

  /// 진행 중인 재발급. 동시에 401 을 받은 요청들이 **각자 refresh 를 호출하지 않도록**
  /// 하나의 Future 를 공유한다. (예: 관제 지도 3초 폴링 + 알림 조회가 같이 만료를 맞는 경우)
  Future<bool>? _inFlightRefresh;

  /// 재시도한 요청인지 표시하는 키 — 무한 재시도 방지.
  static const _retriedKey = 'auth_retried';

  /// 토큰이 필요 없고, 401 을 받아도 재발급을 시도하면 안 되는 경로.
  /// (`/api/auth/refresh` 가 401 이면 그건 재발급 자체가 실패한 것이다)
  static bool _isAuthPath(String path) => path.startsWith('/api/auth/');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthPath(options.path)) {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = request.extra[_retriedKey] == true;

    if (!isUnauthorized || alreadyRetried || _isAuthPath(request.path)) {
      return handler.next(err);
    }

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      _onSessionExpired();
      return handler.next(err);
    }

    try {
      handler.resolve(await _retry(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// 여러 요청이 동시에 불러도 재발급은 한 번만 실행된다.
  Future<bool> _refreshOnce() {
    final inFlight = _inFlightRefresh;
    if (inFlight != null) return inFlight;

    final started = _refreshTokens().whenComplete(
      () => _inFlightRefresh = null,
    );
    _inFlightRefresh = started;
    return started;
  }

  /// 새 토큰으로 원 요청을 다시 보낸다.
  Future<Response<dynamic>> _retry(RequestOptions request) async {
    final token = await _storage.readAccessToken();
    return _retryDio.fetch<dynamic>(
      request.copyWith(
        headers: {
          ...request.headers,
          if (token != null) 'Authorization': 'Bearer $token',
        },
        extra: {...request.extra, _retriedKey: true},
      ),
    );
  }
}
