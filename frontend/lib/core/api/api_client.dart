import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'interceptor/logging_interceptor.dart';

/// HTTP 접근의 유일한 통로.
///
/// **dio 는 이 클래스 밖으로 새지 않는다.** repository 는 [get]/[post]/[patch] 만 쓰고,
/// application·presentation 은 dio 를 import 하지 않는다(컨벤션 §3, 검사 C-1).
/// 덕분에 나중에 http 패키지나 gRPC 로 바꿔도 고칠 곳이 여기 하나다.
///
/// 이 클래스가 책임지는 것 세 가지:
///  1. 공통 응답 봉투(`{success, data, message}`) 벗기기
///  2. 실패를 전부 [ApiException] 으로 통일 (dio 예외를 밖으로 내보내지 않음)
///  3. null 인 쿼리 파라미터 제거 (선택 파라미터를 `null` 문자열로 보내는 사고 방지)
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  /// 기본 설정으로 조립한다. [extraInterceptors] 로 인증 인터셉터(C4)를 끼운다 —
  /// 인증을 여기서 직접 알지 않게 해서, 로그인 없는 요청도 같은 클라이언트를 쓸 수 있다.
  factory ApiClient.create({List<Interceptor> extraInterceptors = const []}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    dio.interceptors.addAll(extraInterceptors);
    // 로깅은 디버그 빌드에서만. 릴리즈 번들에 요청 로그를 남기지 않는다.
    if (kDebugMode) dio.interceptors.add(const LoggingInterceptor());
    return ApiClient(dio);
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? data) decode,
  }) {
    return _send(
      () => _dio.get<dynamic>(path, queryParameters: _clean(query)),
      decode,
    );
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required T Function(Object? data) decode,
  }) {
    return _send(
      () =>
          _dio.post<dynamic>(path, data: body, queryParameters: _clean(query)),
      decode,
    );
  }

  Future<T> patch<T>(
    String path, {
    Object? body,
    required T Function(Object? data) decode,
  }) {
    return _send(() => _dio.patch<dynamic>(path, data: body), decode);
  }

  /// 요청 실행 → 봉투 해제 → 실패는 [ApiException] 으로 통일.
  Future<T> _send<T>(
    Future<Response<dynamic>> Function() call,
    T Function(Object? data) decode,
  ) async {
    final Response<dynamic> response;
    try {
      response = await call();
    } on DioException catch (e) {
      throw _toApiException(e);
    }

    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw ApiException.malformed('${body.runtimeType}');
    }

    final ApiResponse<T> envelope;
    try {
      envelope = ApiResponse.fromJson<T>(body, decode);
    } on FormatException catch (e) {
      throw ApiException.malformed(e.message);
    }

    // HTTP 2xx 인데 success=false 인 경우까지 방어한다.
    // 현재 백엔드는 실패를 항상 non-2xx 로 주지만, 계약이 바뀌어도 조용히 통과하지 않게 한다.
    if (!envelope.success) {
      throw ApiException.fromStatus(response.statusCode, envelope.message);
    }
    return envelope.data as T;
  }

  ApiException _toApiException(DioException e) {
    // 서버가 응답을 준 경우 — status 로 갈래를 정하고, 본문의 message 를 그대로 쓴다.
    final response = e.response;
    if (response != null) {
      final data = response.data;
      final serverMessage = data is Map<String, dynamic>
          ? data['message'] as String?
          : null;
      return ApiException.fromStatus(response.statusCode, serverMessage);
    }

    // 서버에 닿지 못한 경우 — status 자체가 없다.
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiException.network(
        '서버 응답이 지연되고 있습니다',
      ),
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => ApiException.network(),
      DioExceptionType.cancel => const ApiException(
        kind: ApiErrorKind.unknown,
        message: '요청이 취소되었습니다',
      ),
      _ => ApiException.malformed(e.message),
    };
  }

  /// 값이 null 인 쿼리 파라미터를 버린다.
  ///
  /// 백엔드의 선택 파라미터(`tenantId`, `date`, `serviceDate`)는 **생략하면 기본값**이
  /// 적용되지만, `?date=null` 로 보내면 파싱 오류(400)가 난다.
  static Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value,
    };
    return cleaned.isEmpty ? null : cleaned;
  }
}

/// 앱 전역 [ApiClient].
///
/// C4 에서 인증 인터셉터를 `extraInterceptors` 로 끼우도록 이 provider 를 확장한다.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.create());
