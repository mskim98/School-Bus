import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/api/api_client.dart';
import 'package:school_bus/features/location/data/location_repository.dart';
import 'package:school_bus/features/location/domain/monitored_bus.dart';

/// 서버 대신 정해진 응답을 돌려주는 어댑터(`api_client_test` 와 같은 방식).
class _FakeAdapter implements HttpClientAdapter {
  String body = '{"success":true,"data":null,"message":null}';
  int statusCode = 200;
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
  late LocationRepository repository;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    repository = LocationRepository(ApiClient(dio));
  });

  group('reportBusLocation — POST /api/locations/bus', () {
    test('busId·lat·lng·origin 을 계약대로 보낸다', () async {
      await repository.reportBusLocation(
        busId: 1,
        lat: 37.5075,
        lng: 127.0355,
        origin: LocationOrigin.gps,
      );

      final request = adapter.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, '/api/locations/bus');
      expect(request.data, {
        'busId': 1,
        'lat': 37.5075,
        'lng': 127.0355,
        'origin': 'GPS',
      });
    });

    test('★ Mock 출처는 대문자 "MOCK" 으로 나간다 — 서버 enum 과 글자까지 같아야 한다', () async {
      await repository.reportBusLocation(
        busId: 1,
        lat: 37.5,
        lng: 127.0,
        origin: LocationOrigin.mock,
      );

      expect((adapter.lastRequest!.data! as Map)['origin'], 'MOCK');
    });

    test('응답 data 가 null 이어도 성공으로 본다', () async {
      // 서버는 본문 없는 성공을 이렇게 준다(실측).
      adapter.body = '{"success":true,"data":null,"message":null}';

      await expectLater(
        repository.reportBusLocation(
          busId: 1,
          lat: 37.5,
          lng: 127.0,
          origin: LocationOrigin.gps,
        ),
        completes,
      );
    });
  });

  group('getBusLocations — GET /api/locations/buses', () {
    test('★ tenantId 가 null 이면 쿼리에서 아예 뺀다 — ?tenantId=null 은 400 이다', () async {
      adapter.body = jsonEncode({'success': true, 'data': <Object>[]});

      await repository.getBusLocations();

      expect(adapter.lastRequest!.queryParameters, isEmpty);
    });

    test('tenantId 를 주면 쿼리에 붙는다 (PLATFORM_ADMIN 은 필수)', () async {
      adapter.body = jsonEncode({'success': true, 'data': <Object>[]});

      await repository.getBusLocations(tenantId: 1);

      expect(adapter.lastRequest!.queryParameters, {'tenantId': 1});
    });

    test('빈 배열은 에러가 아니다 — "아직 아무도 보고하지 않음"이다', () async {
      adapter.body = jsonEncode({'success': true, 'data': <Object>[]});

      expect(await repository.getBusLocations(tenantId: 1), isEmpty);
    });

    test('실측 응답을 DTO 로 읽는다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': [
          {
            'busId': 1,
            'busName': '3호차',
            'lat': 37.5075,
            'lng': 127.0355,
            'recordedAt': '2026-07-28T12:34:26.199274169',
            'origin': 'MOCK',
          },
        ],
        'message': null,
      });

      final result = await repository.getBusLocations(tenantId: 1);

      expect(result, hasLength(1));
      expect(result.single.busId, 1);
      expect(result.single.busName, '3호차');
      expect(result.single.origin, 'MOCK');
    });
  });

  group('getBuses — GET /api/buses', () {
    test('관제에 필요한 필드만 읽고, 기사 미배차는 null 로 남긴다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': [
          {
            'id': 1,
            'tenantId': 1,
            'name': '3호차',
            'plateNumber': '서울12가3456',
            'seatCapacity': 25,
            'driverName': '박기사',
          },
          {
            'id': 2,
            'tenantId': 1,
            'name': '1호차',
            'plateNumber': '서울34나5678',
            'driverId': null,
            'driverName': null,
          },
        ],
      });

      final result = await repository.getBuses(tenantId: 1);

      expect(result, hasLength(2));
      expect(result.first.driverName, '박기사');
      expect(result.last.driverName, isNull, reason: '1호차는 기사 미배차');
      expect(result.last.plateNumber, '서울34나5678');
    });
  });
}
