import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/api/api_client.dart';
import 'package:school_bus/core/api/api_exception.dart';
import 'package:school_bus/core/api/api_response.dart';

/// 서버 대신 정해진 응답을 돌려주는 어댑터. 네트워크 없이 [ApiClient] 를 검증한다.
class _FakeAdapter implements HttpClientAdapter {
  // 각 테스트가 필요한 값만 골라 덮어쓰도록 필드로만 둔다.
  int statusCode = 200;
  String body = '{}';
  DioException? throwError;

  /// 마지막 요청 — 쿼리 파라미터 정리 검증에 쓴다.
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (throwError != null) throw throwError!;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 테스트용 모델 — DTO 없이 디코더 동작만 본다.
class _Bus {
  const _Bus(this.id, this.name);
  final int id;
  final String name;

  static _Bus fromJson(Map<String, dynamic> json) =>
      _Bus(json['id'] as int, json['name'] as String);
}

void main() {
  late _FakeAdapter adapter;
  late ApiClient client;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    client = ApiClient(dio);
  });

  group('응답 봉투 해제', () {
    test('success=true 면 data 만 꺼내 돌려준다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': {'id': 1, 'name': '3호차'},
        'message': null,
      });

      final bus = await client.get(
        '/api/buses/me',
        decode: Decode.one(_Bus.fromJson),
      );

      expect(bus.id, 1);
      expect(bus.name, '3호차');
    });

    test('빈 배열은 에러가 아니라 빈 목록이다', () async {
      adapter.body = jsonEncode({'success': true, 'data': [], 'message': null});

      final list = await client.get(
        '/api/ride-events/children',
        decode: Decode.list(_Bus.fromJson),
      );

      expect(list, isEmpty);
    });

    test('data 가 null 인 응답(위치 보고)은 void 로 통과한다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': null,
        'message': null,
      });

      await expectLater(
        client.post('/api/locations/bus', decode: Decode.unit),
        completes,
      );
    });

    test('HTTP 200 인데 success=false 면 예외로 만든다', () async {
      adapter.body = jsonEncode({
        'success': false,
        'data': null,
        'message': '담당 기사만 처리할 수 있습니다',
      });

      await expectLater(
        client.get('/api/buses/me', decode: Decode.one(_Bus.fromJson)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            '담당 기사만 처리할 수 있습니다',
          ),
        ),
      );
    });

    test('계약과 다른 응답(배열 자리에 객체)은 malformed 로 바뀐다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': {'id': 1},
        'message': null,
      });

      await expectLater(
        client.get('/api/buses', decode: Decode.list(_Bus.fromJson)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.unknown,
          ),
        ),
      );
    });
  });

  group('HTTP status → ApiException', () {
    Future<ApiException> callWithStatus(int status, {String? message}) async {
      adapter
        ..statusCode = status
        ..body = jsonEncode({
          'success': false,
          'data': null,
          'message': message,
        });
      try {
        await client.get('/x', decode: Decode.one(_Bus.fromJson));
        fail('예외가 발생해야 한다');
      } on ApiException catch (e) {
        return e;
      }
    }

    test('status 별 갈래가 정확히 매핑된다', () async {
      expect((await callWithStatus(400)).kind, ApiErrorKind.badRequest);
      expect((await callWithStatus(401)).kind, ApiErrorKind.unauthorized);
      expect((await callWithStatus(403)).kind, ApiErrorKind.forbidden);
      expect((await callWithStatus(404)).kind, ApiErrorKind.notFound);
      expect((await callWithStatus(409)).kind, ApiErrorKind.conflict);
      expect((await callWithStatus(500)).kind, ApiErrorKind.server);
      expect((await callWithStatus(503)).kind, ApiErrorKind.server);
    });

    test('서버 message 가 있으면 그대로 쓴다', () async {
      final e = await callWithStatus(404, message: '담당 버스가 없습니다');
      expect(e.message, '담당 버스가 없습니다');
      expect(e.statusCode, 404);
    });

    test('서버 message 가 없으면 갈래별 기본 문구를 쓴다', () async {
      expect((await callWithStatus(403)).message, '접근 권한이 없습니다');
    });

    test('401 만 refresh 재시도 대상이다', () async {
      expect((await callWithStatus(401)).isRetriableWithRefresh, isTrue);
      expect((await callWithStatus(403)).isRetriableWithRefresh, isFalse);
    });
  });

  group('네트워크 실패', () {
    test('연결 실패는 status 없는 network 예외가 된다', () async {
      adapter.throwError = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );

      await expectLater(
        client.get('/x', decode: Decode.one(_Bus.fromJson)),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.network)
              .having((e) => e.statusCode, 'statusCode', isNull),
        ),
      );
    });

    test('타임아웃도 network 갈래로 접힌다', () async {
      adapter.throwError = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.receiveTimeout,
      );

      await expectLater(
        client.get('/x', decode: Decode.one(_Bus.fromJson)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.network,
          ),
        ),
      );
    });
  });

  group('쿼리 파라미터 정리', () {
    setUp(() {
      adapter.body = jsonEncode({'success': true, 'data': [], 'message': null});
    });

    test('null 값은 아예 보내지 않는다 — ?date=null 로 400 나는 걸 막는다', () async {
      await client.get(
        '/api/ride-events/children',
        query: {'date': null, 'tenantId': 1},
        decode: Decode.list(_Bus.fromJson),
      );

      expect(adapter.lastRequest!.queryParameters, {'tenantId': 1});
    });

    test('전부 null 이면 쿼리 자체가 붙지 않는다', () async {
      await client.get(
        '/api/route-plans',
        query: {'tenantId': null, 'busId': null},
        decode: Decode.list(_Bus.fromJson),
      );

      expect(adapter.lastRequest!.queryParameters, isEmpty);
    });
  });
}
