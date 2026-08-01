import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/api/api_client.dart';
import 'package:school_bus/core/api/api_exception.dart';
import 'package:school_bus/features/bus/data/bus_repository.dart';

/// 서버 대신 정해진 응답을 돌려주는 어댑터(`location_repository_test` 와 같은 방식).
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
  late BusRepository repository;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    repository = BusRepository(ApiClient(dio));
  });

  group('findMyBus — GET /api/buses/me', () {
    test('시드 응답을 도메인으로 읽는다', () async {
      // 시드의 3호차(디자인 시스템 §9). 서버 `BusResponse` 전체를 그대로 준다 —
      // 안 쓰는 필드가 섞여 와도 파싱이 깨지지 않아야 한다.
      adapter.body = jsonEncode({
        'success': true,
        'data': {
          'id': 1,
          'tenantId': 1,
          'name': '3호차',
          'plateNumber': '서울12가3456',
          'seatCapacity': 25,
          'assignCapacity': 30,
          'onboard': 3,
          'overCapacity': false,
          'driverId': 3,
          'driverName': '박기사',
          'routeId': 1,
          'routeName': '하원 A노선',
          'insuranceExpiry': '2027-03-31',
        },
        'message': null,
      });

      final bus = await repository.findMyBus();

      expect(adapter.lastRequest!.method, 'GET');
      expect(adapter.lastRequest!.path, '/api/buses/me');
      expect(bus, isNotNull);
      expect(bus!.displayName, '3호차');
      expect(bus.plateLabel, '서울12가3456');
      expect(bus.seatCapacity, 25);
      expect(bus.assignedCount, 3, reason: '서버 onboard = 배정 학생 수');
      expect(bus.routeLabel, '하원 A노선');
    });

    test('★ 담당 버스가 없으면(404) 예외가 아니라 null 이다', () async {
      // 배차 전 기사 — 오류가 아니라 정상 상태다(`auth_repository.fetchMyBusId` 와 동일).
      adapter.statusCode = 404;
      adapter.body = jsonEncode({
        'success': false,
        'data': null,
        'message': '담당 버스가 없습니다',
      });

      expect(await repository.findMyBus(), isNull);
    });

    test('404 가 아닌 실패는 그대로 올린다 — 조용히 삼키지 않는다', () async {
      adapter.statusCode = 403;
      adapter.body = jsonEncode({
        'success': false,
        'data': null,
        'message': '접근 권한이 없습니다',
      });

      await expectLater(
        repository.findMyBus(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.kind,
            'kind',
            ApiErrorKind.forbidden,
          ),
        ),
      );
    });

    test('노선 미배정 버스는 routeName 이 null 로 온다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': {
          'id': 2,
          'name': '1호차',
          'plateNumber': '서울34나5678',
          'seatCapacity': 15,
          'assignCapacity': null,
          'onboard': 0,
          'routeId': null,
          'routeName': null,
        },
      });

      final bus = await repository.findMyBus();

      expect(bus!.routeLabel, isNull);
      expect(bus.assignedCount, 0);
    });
  });
}
