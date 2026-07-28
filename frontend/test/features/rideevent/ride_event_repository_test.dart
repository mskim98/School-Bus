import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/api/api_client.dart';
import 'package:school_bus/core/api/api_exception.dart';
import 'package:school_bus/features/rideevent/data/ride_event_repository.dart';
import 'package:school_bus/features/rideevent/domain/ride_event.dart';

/// 서버 대신 정해진 응답을 돌려주는 어댑터.
class _FakeAdapter implements HttpClientAdapter {
  int statusCode = 200;
  String body = '{}';
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
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

void main() {
  late _FakeAdapter adapter;
  late RideEventRepository repository;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    repository = RideEventRepository(ApiClient(dio));
  });

  Map<String, dynamic> recorded({
    int id = 1,
    int studentId = 1,
    String type = 'BOARD',
    String occurredAt = '2026-07-28T12:33:58.674138378',
  }) => {
    'id': id,
    'tenantId': 1,
    'studentId': studentId,
    'busId': 1,
    'stopId': 1,
    'type': type,
    'occurredAt': occurredAt,
    'lat': null,
    'lng': null,
    'source': 'MANUAL',
  };

  group('승하차 기록', () {
    test('필수 필드만 보낸다 — source 는 서버가 MANUAL 로 채운다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': recorded(),
        'message': null,
      });

      await repository.record(
        busId: 1,
        studentId: 1,
        type: RideEventType.board,
      );

      final sent = adapter.lastRequest!;
      expect(sent.path, '/api/ride-events');
      expect(sent.data, {'busId': 1, 'studentId': 1, 'type': 'BOARD'});
      expect(
        (sent.data as Map).containsKey('stopId'),
        isFalse,
        reason: 'null 을 보내면 서버 기본 정류장이 안 잡힌다',
      );
    });

    test('좌표를 주면 함께 보낸다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': recorded(type: 'ALIGHT'),
        'message': null,
      });

      await repository.record(
        busId: 1,
        studentId: 1,
        type: RideEventType.alight,
        stopId: 2,
        lat: 37.501,
        lng: 127.0275,
      );

      expect(adapter.lastRequest!.data, {
        'busId': 1,
        'studentId': 1,
        'type': 'ALIGHT',
        'stopId': 2,
        'lat': 37.501,
        'lng': 127.0275,
      });
    });

    test('★ 서버가 실제로 기록한 종류를 돌려준다 — 화면은 이 값으로만 단계를 옮긴다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': recorded(type: 'HANDOVER'),
        'message': null,
      });

      final event = await repository.record(
        busId: 1,
        studentId: 1,
        type: RideEventType.handover,
      );

      expect(event.type, RideEventType.handover);
      expect(event.studentId, 1);
    });

    test('실패는 삼키지 않는다 — 기사가 잘못 안심하면 안 된다', () async {
      adapter.statusCode = 403;
      adapter.body = jsonEncode({
        'success': false,
        'data': null,
        'message': '담당 버스가 아닙니다',
      });

      await expectLater(
        repository.record(busId: 1, studentId: 1, type: RideEventType.board),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.forbidden)
              .having((e) => e.message, 'message', '담당 버스가 아닙니다'),
        ),
      );
    });
  });

  group('그날 이력', () {
    test('date 를 yyyy-MM-dd 로 붙인다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': [recorded()],
        'message': null,
      });

      await repository.busRecords(busId: 1, date: DateTime(2026, 7, 8));

      expect(adapter.lastRequest!.path, '/api/ride-events/bus/1');
      expect(adapter.lastRequest!.queryParameters, {'date': '2026-07-08'});
    });

    test('빈 배열은 에러가 아니다 — 아직 아무도 안 탄 것뿐이다', () async {
      adapter.body = jsonEncode({'success': true, 'data': [], 'message': null});

      expect(
        await repository.busRecords(busId: 1, date: DateTime(2026, 7, 28)),
        isEmpty,
      );
    });

    test('모르는 종류의 기록 한 건 때문에 명단 전체가 죽지 않는다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': [
          recorded(id: 1, type: 'BOARD'),
          recorded(id: 2, studentId: 2, type: 'TELEPORT'),
          recorded(id: 3, studentId: 3, type: 'ALIGHT'),
        ],
        'message': null,
      });

      final events = await repository.busRecords(
        busId: 1,
        date: DateTime(2026, 7, 28),
      );

      expect(events, hasLength(2));
      expect(events.map((e) => e.studentId), [1, 3]);
    });
  });
}
