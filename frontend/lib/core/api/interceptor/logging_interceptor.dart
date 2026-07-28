import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 개발 중 요청/응답을 한 줄로 남긴다. 릴리즈 빌드에는 붙이지 않는다([ApiClient] 참조).
///
/// `print()` 대신 [debugPrint] 를 쓴다(컨벤션 §8) — debugPrint 는 출력이 몰릴 때
/// 조절해 주고, 릴리즈에서 통째로 제거하기도 쉽다.
///
/// ⚠️ 토큰을 그대로 찍지 않는다. Authorization 헤더는 존재 여부만 남긴다 —
/// 로그에 남은 accessToken 이 그대로 유출되는 사고를 막기 위함이다.
class LoggingInterceptor extends Interceptor {
  const LoggingInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final hasAuth = options.headers.containsKey('Authorization');
    debugPrint('→ ${options.method} ${options.uri}${hasAuth ? ' [auth]' : ''}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '✗ ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.uri}',
    );
    handler.next(err);
  }
}
