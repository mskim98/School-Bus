import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/api/interceptor/auth_interceptor.dart';
import 'package:school_bus/core/storage/spec/token_storage.dart';

/// 테스트용 인메모리 토큰 저장소 — [TokenStorage] 를 포트로 둔 덕에 그대로 갈아끼운다.
class _MemoryTokenStorage implements TokenStorage {
  String? access;
  String? refresh;

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

/// 401 을 먼저 주고, 토큰이 바뀌면 200 을 주는 가짜 서버.
class _ExpiringAdapter implements HttpClientAdapter {
  _ExpiringAdapter({required this.validToken});

  String validToken;

  /// 요청마다 실려 온 Authorization 헤더 기록 — 재시도 시 새 토큰을 썼는지 본다.
  final List<String?> seenAuthHeaders = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    seenAuthHeaders.add(auth);

    final ok = auth == 'Bearer $validToken';
    return ResponseBody.fromString(
      jsonEncode({
        'success': ok,
        'data': ok ? {'ok': true} : null,
        'message': ok ? null : '인증이 필요합니다',
      }),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _MemoryTokenStorage storage;
  late _ExpiringAdapter adapter;
  late int refreshCallCount;
  late int sessionExpiredCount;

  /// 재발급 성공을 흉내낸다 — 저장소의 accessToken 을 서버가 인정하는 값으로 바꾼다.
  Dio buildDio({required bool refreshSucceeds}) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        refreshTokens: () async {
          refreshCallCount++;
          // 실제 재발급도 네트워크를 타므로 한 틱 쉬어 동시성을 재현한다.
          await Future<void>.delayed(const Duration(milliseconds: 10));
          if (!refreshSucceeds) return false;
          storage.access = 'new-token';
          return true;
        },
        onSessionExpired: () => sessionExpiredCount++,
        // 재시도도 같은 가짜 서버를 타야 검증이 된다.
        retryDio: Dio(BaseOptions(baseUrl: 'http://test'))
          ..httpClientAdapter = adapter,
      ),
    );
    return dio;
  }

  setUp(() {
    storage = _MemoryTokenStorage()
      ..access = 'old-token'
      ..refresh = 'refresh-token';
    adapter = _ExpiringAdapter(validToken: 'new-token');
    refreshCallCount = 0;
    sessionExpiredCount = 0;
  });

  test('저장된 accessToken 을 Authorization 헤더로 붙인다', () async {
    adapter.validToken = 'old-token';
    final dio = buildDio(refreshSucceeds: true);

    await dio.get<dynamic>('/api/buses/me');

    expect(adapter.seenAuthHeaders.first, 'Bearer old-token');
  });

  test('/api/auth/* 에는 토큰을 붙이지 않는다', () async {
    adapter.validToken = 'old-token';
    final dio = buildDio(refreshSucceeds: true);

    // 로그인은 토큰 없이 나가야 한다 — 401 이 나도 재발급을 시도하면 안 된다.
    await dio
        .post<dynamic>('/api/auth/login')
        .catchError((_) => Response<dynamic>(requestOptions: RequestOptions()));

    expect(adapter.seenAuthHeaders.first, isNull);
    expect(refreshCallCount, 0);
  });

  test('401 을 받으면 재발급 후 새 토큰으로 원 요청을 재시도한다', () async {
    final dio = buildDio(refreshSucceeds: true);

    final response = await dio.get<dynamic>('/api/buses/me');

    expect(response.statusCode, 200);
    expect(refreshCallCount, 1);
    expect(adapter.seenAuthHeaders, ['Bearer old-token', 'Bearer new-token']);
    expect(sessionExpiredCount, 0);
  });

  test('동시에 401 을 받아도 재발급은 한 번만 호출된다 ★', () async {
    final dio = buildDio(refreshSucceeds: true);

    // 관제 지도 3초 폴링과 알림 조회가 동시에 만료를 맞는 상황.
    final responses = await Future.wait([
      dio.get<dynamic>('/api/locations/buses'),
      dio.get<dynamic>('/api/notifications'),
      dio.get<dynamic>('/api/route-plans'),
    ]);

    expect(responses.every((r) => r.statusCode == 200), isTrue);
    expect(
      refreshCallCount,
      1,
      reason: '뮤텍스가 없으면 요청 수만큼 refresh 가 호출돼 토큰 회전이 어긋난다',
    );
  });

  test('재발급이 실패하면 세션 만료를 알리고 원래 401 을 올려보낸다', () async {
    final dio = buildDio(refreshSucceeds: false);

    await expectLater(
      dio.get<dynamic>('/api/buses/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    expect(refreshCallCount, 1);
    expect(sessionExpiredCount, 1);
  });

  test('재시도한 요청이 또 401 이어도 무한 반복하지 않는다', () async {
    // 재발급은 "성공"했다고 하지만 서버는 그 토큰도 거절하는 상황.
    adapter.validToken = 'never-matches';
    final dio = buildDio(refreshSucceeds: true);

    await expectLater(
      dio.get<dynamic>('/api/buses/me'),
      throwsA(isA<DioException>()),
    );

    expect(refreshCallCount, 1, reason: '재시도 요청은 다시 재발급을 트리거하면 안 된다');
    expect(adapter.seenAuthHeaders.length, 2, reason: '원 요청 1 + 재시도 1');
  });
}
