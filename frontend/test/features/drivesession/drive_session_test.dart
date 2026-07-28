import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/drivesession/data/dto/drive_session_dto.dart';
import 'package:school_bus/features/drivesession/domain/drive_session.dart';

void main() {
  /// 2026-07-28 실제 서버 응답 형태(`POST /api/drive-sessions/start`).
  Map<String, dynamic> startedJson({
    String status = 'IN_PROGRESS',
    String? endedAt,
  }) => {
    'id': 2,
    'tenantId': 1,
    'busId': 1,
    'driverId': 3,
    'direction': 'PICKUP',
    'serviceDate': '2026-07-28',
    'routePlanId': null,
    'status': status,
    'startedAt': '2026-07-28T12:33:58.649328087',
    'endedAt': endedAt,
  };

  group('DriveSession.fromDto', () {
    test('방향·상태·시각이 모두 변환된다', () {
      final session = DriveSession.fromDto(
        DriveSessionDto.fromJson(startedJson()),
      );

      expect(session.id, 2);
      expect(session.busId, 1);
      expect(session.direction, DriveDirection.pickup);
      expect(session.direction.label, '등원');
      expect(session.isInProgress, isTrue);
      expect(session.serviceDate, DateTime(2026, 7, 28));
    });

    test('★ startedAt 의 소수점 9자리를 파싱한다 — 서버가 나노초까지 준다', () {
      final session = DriveSession.fromDto(
        DriveSessionDto.fromJson(startedJson()),
      );

      // 마이크로초까지만 남고 그 아래(087)는 잘린다.
      expect(session.startedAt.hour, 12);
      expect(session.startedAt.minute, 33);
      expect(session.startedAt.second, 58);
      expect(session.startedAt.millisecond, 649);
      expect(session.startedAt.microsecond, 328);
    });

    test('COMPLETED 는 진행 중이 아니고, 소요 시간이 나온다', () {
      final session = DriveSession.fromDto(
        DriveSessionDto.fromJson(
          startedJson(
            status: 'COMPLETED',
            endedAt: '2026-07-28T12:43:58.649328087',
          ),
        ),
      );

      expect(session.isInProgress, isFalse);
      expect(session.elapsed, const Duration(minutes: 10));
    });

    test('진행 중이면 endedAt 도 소요 시간도 없다', () {
      final session = DriveSession.fromDto(
        DriveSessionDto.fromJson(startedJson()),
      );

      expect(session.endedAt, isNull);
      expect(session.elapsed, isNull);
    });

    test('모르는 방향 값이 와도 죽지 않는다', () {
      final dto = DriveSessionDto.fromJson({
        ...startedJson(),
        'direction': 'FUTURE_DIRECTION',
      });

      expect(() => DriveSession.fromDto(dto), returnsNormally);
      expect(DriveSession.fromDto(dto).direction, DriveDirection.pickup);
    });
  });

  group('DriveDirection', () {
    test('서버 값 ↔ 한글 이름', () {
      expect(DriveDirection.fromWire('DROPOFF'), DriveDirection.dropoff);
      expect(DriveDirection.dropoff.label, '하원');
      expect(DriveDirection.pickup.wireName, 'PICKUP');
    });

    test('모르는 값·null 은 null', () {
      expect(DriveDirection.fromWire('ROUND_TRIP'), isNull);
      expect(DriveDirection.fromWire(null), isNull);
    });
  });

  group('RosterEntry.fromDto — 시드 데이터 기준', () {
    test('이름과 장소가 그대로 넘어온다', () {
      final entry = RosterEntry.fromDto(
        DriveSessionRosterEntryDto.fromJson({
          'studentId': 1,
          'name': '김민준',
          'location': '정류장 A',
          'lat': 37.501,
          'lng': 127.0275,
        }),
      );

      expect(entry.studentId, 1);
      expect(entry.name, '김민준');
      expect(entry.location, '정류장 A');
    });

    test('좌표·장소가 없어도 이름은 살아 있다 — 하차지 좌표 없는 학생이 실제로 있다', () {
      final entry = RosterEntry.fromDto(
        DriveSessionRosterEntryDto.fromJson({
          'studentId': 4,
          'name': '최지우',
          'location': null,
          'lat': null,
          'lng': null,
        }),
      );

      expect(entry.name, '최지우');
      expect(entry.location, isNull);
    });
  });
}
