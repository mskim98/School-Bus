import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/api/api_client.dart';
import 'package:school_bus/core/api/api_exception.dart';
import 'package:school_bus/features/drivesession/data/drive_session_repository.dart';
import 'package:school_bus/features/drivesession/domain/drive_session.dart';

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
  late DriveSessionRepository repository;

  setUp(() {
    adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    repository = DriveSessionRepository(ApiClient(dio));
  });

  Map<String, dynamic> session({
    required int id,
    String status = 'IN_PROGRESS',
    String direction = 'PICKUP',
  }) => {
    'id': id,
    'tenantId': 1,
    'busId': 1,
    'driverId': 3,
    'direction': direction,
    'serviceDate': '2026-07-28',
    'routePlanId': null,
    'status': status,
    'startedAt': '2026-07-28T12:33:58.649328087',
    'endedAt': status == 'COMPLETED' ? '2026-07-28T12:34:10.867671134' : null,
  };

  group('운행 시작', () {
    test('busId 와 방향을 서버 값으로 보낸다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': session(id: 1, direction: 'DROPOFF'),
        'message': null,
      });

      final started = await repository.start(
        busId: 1,
        direction: DriveDirection.dropoff,
      );

      final sent = adapter.lastRequest!;
      expect(sent.path, '/api/drive-sessions/start');
      expect(sent.method, 'POST');
      expect(sent.data, {'busId': 1, 'direction': 'DROPOFF'});
      expect(started.id, 1);
      expect(started.isInProgress, isTrue);
    });

    test('★ 이미 운행 중이면 409 — 실패를 삼키지 않고 그대로 올린다', () async {
      adapter.statusCode = 409;
      adapter.body = jsonEncode({
        'success': false,
        'data': null,
        'message': '이미 진행 중인 운행이 있습니다',
      });

      await expectLater(
        repository.start(busId: 1, direction: DriveDirection.pickup),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.conflict)
              .having((e) => e.message, 'message', '이미 진행 중인 운행이 있습니다'),
        ),
      );
    });
  });

  group('진행 중 운행 찾기', () {
    test('★ 이력에서 IN_PROGRESS 하나를 고른다 — 앱을 껐다 켜도 운행이 이어진다', () async {
      // 서버는 최신순으로 준다.
      adapter.body = jsonEncode({
        'success': true,
        'data': [
          session(id: 3),
          session(id: 2, status: 'COMPLETED'),
          session(id: 1, status: 'COMPLETED'),
        ],
        'message': null,
      });

      final active = await repository.findActive(1);

      expect(active, isNotNull);
      expect(active!.id, 3);
    });

    test('전부 끝났으면 null — 운행 전 상태다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': [session(id: 1, status: 'COMPLETED')],
        'message': null,
      });

      expect(await repository.findActive(1), isNull);
    });

    test('이력이 비어도 에러가 아니다', () async {
      adapter.body = jsonEncode({'success': true, 'data': [], 'message': null});

      expect(await repository.findActive(1), isNull);
    });
  });

  group('명단', () {
    test('학생 이름을 얻는 유일한 경로', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': [
          {
            'studentId': 1,
            'name': '김민준',
            'location': '정류장 A',
            'lat': 37.501,
            'lng': 127.0275,
          },
          {
            'studentId': 3,
            'name': '박도윤',
            'location': '정류장 B',
            'lat': 37.5045,
            'lng': 127.031,
          },
        ],
        'message': null,
      });

      final roster = await repository.roster(2);

      expect(adapter.lastRequest!.path, '/api/drive-sessions/2/roster');
      expect(roster.map((e) => e.name), ['김민준', '박도윤']);
    });
  });

  group('운행 종료', () {
    test('종료되면 COMPLETED 로 온다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': session(id: 2, status: 'COMPLETED'),
        'message': null,
      });

      final ended = await repository.end(2);

      expect(adapter.lastRequest!.method, 'PATCH');
      expect(adapter.lastRequest!.path, '/api/drive-sessions/2/end');
      expect(ended.isInProgress, isFalse);
      expect(ended.elapsed, isNotNull);
    });

    test('★ 잔류 학생이 있으면 409 — 안전장치라 우회하지 않는다', () async {
      adapter.statusCode = 409;
      adapter.body = jsonEncode({
        'success': false,
        'data': null,
        'message': '하차 처리되지 않은 학생이 있어 운행을 종료할 수 없습니다',
      });

      await expectLater(
        repository.end(2),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiErrorKind.conflict)
              .having(
                (e) => e.message,
                'message',
                '하차 처리되지 않은 학생이 있어 운행을 종료할 수 없습니다',
              ),
        ),
      );
    });
  });
}
