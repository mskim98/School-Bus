import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/drivesession/domain/drive_session.dart';
import 'package:school_bus/features/rideevent/data/dto/ride_event_dto.dart';
import 'package:school_bus/features/rideevent/domain/ride_event.dart';
import 'package:school_bus/features/rideevent/domain/roster_student.dart';

void main() {
  /// 3호차 시드 명단 — 딱 3명이다.
  const seedRoster = [
    RosterEntry(studentId: 1, name: '김민준', location: '정류장 A'),
    RosterEntry(studentId: 2, name: '이서연', location: '정류장 A'),
    RosterEntry(studentId: 3, name: '박도윤', location: '정류장 B'),
  ];

  final sessionStart = DateTime(2026, 7, 28, 12, 33);

  RideEvent event(
    int studentId,
    RideEventType type, {
    required DateTime at,
    int id = 0,
  }) => RideEvent(id: id, studentId: studentId, type: type, occurredAt: at);

  group('RosterStudent.merge — 명단 ⋈ 승하차 기록', () {
    test('기록이 없으면 전원 대기', () {
      final students = RosterStudent.merge(
        roster: seedRoster,
        events: const [],
        since: sessionStart,
      );

      expect(students, hasLength(3));
      expect(students.map((s) => s.status), everyElement(RideStatus.waiting));
      expect(students.first.name, '김민준', reason: '이름은 명단에서만 온다');
      expect(students.first.location, '정류장 A');
    });

    test('학생별 마지막 기록이 현재 단계가 된다', () {
      final students = RosterStudent.merge(
        roster: seedRoster,
        events: [
          event(
            1,
            RideEventType.board,
            at: sessionStart.add(const Duration(minutes: 1)),
          ),
          event(
            1,
            RideEventType.alight,
            at: sessionStart.add(const Duration(minutes: 5)),
          ),
          event(
            2,
            RideEventType.board,
            at: sessionStart.add(const Duration(minutes: 2)),
          ),
        ],
        since: sessionStart,
      );

      expect(students[0].status, RideStatus.alighted);
      expect(students[1].status, RideStatus.boarded);
      expect(students[2].status, RideStatus.waiting);
      expect(
        students[0].updatedAt,
        sessionStart.add(const Duration(minutes: 5)),
      );
    });

    test('응답 순서가 뒤죽박죽이어도 가장 늦은 기록을 고른다', () {
      final students = RosterStudent.merge(
        roster: seedRoster,
        events: [
          event(
            1,
            RideEventType.handover,
            at: sessionStart.add(const Duration(minutes: 9)),
          ),
          event(
            1,
            RideEventType.board,
            at: sessionStart.add(const Duration(minutes: 1)),
          ),
        ],
        since: sessionStart,
      );

      expect(students[0].status, RideStatus.handedOver);
    });

    test('★ 세션 시작 이전 기록은 무시한다 — 아침 등원 기록이 오후 하원에 묻어 온다', () {
      // `GET /api/ride-events/bus/{busId}?date=` 는 그날 전부를 준다.
      // 등원 마지막이 ALIGHT 라, 안 거르면 하원 시작부터 "하차 완료"로 보인다.
      final students = RosterStudent.merge(
        roster: seedRoster,
        events: [
          event(1, RideEventType.board, at: DateTime(2026, 7, 28, 8, 10)),
          event(1, RideEventType.alight, at: DateTime(2026, 7, 28, 8, 40)),
        ],
        since: sessionStart,
      );

      expect(students[0].status, RideStatus.waiting);
      expect(students[0].updatedAt, isNull);
    });

    test('명단에 없는 학생의 기록은 화면에 나타나지 않는다', () {
      final students = RosterStudent.merge(
        roster: seedRoster,
        events: [
          event(
            99,
            RideEventType.board,
            at: sessionStart.add(const Duration(minutes: 1)),
          ),
        ],
        since: sessionStart,
      );

      expect(students, hasLength(3));
      expect(students.map((s) => s.studentId), isNot(contains(99)));
    });
  });

  group('다음 동작 — 순서를 클라이언트가 지킨다', () {
    RosterStudent studentWith(RideStatus status) =>
        RosterStudent(studentId: 1, name: '김민준', status: status);

    test('하원(DROPOFF): 대기 → 승차 → 하차 → 인계 → 끝', () {
      const d = DriveDirection.dropoff;

      expect(
        studentWith(RideStatus.waiting).nextActionFor(d),
        RideEventType.board,
      );
      expect(
        studentWith(RideStatus.boarded).nextActionFor(d),
        RideEventType.alight,
      );
      expect(
        studentWith(RideStatus.alighted).nextActionFor(d),
        RideEventType.handover,
      );
      expect(studentWith(RideStatus.handedOver).nextActionFor(d), isNull);
    });

    test('★ 등원(PICKUP)에는 인계 단계가 없다 — 학원에 내려주면 끝이다', () {
      const p = DriveDirection.pickup;

      expect(
        studentWith(RideStatus.boarded).nextActionFor(p),
        RideEventType.alight,
      );
      expect(studentWith(RideStatus.alighted).nextActionFor(p), isNull);
    });

    test('차 안에 있는 학생은 승차 완료 상태 하나뿐 — 운행 종료를 막는 기준이다', () {
      expect(studentWith(RideStatus.boarded).isOnboard, isTrue);
      expect(studentWith(RideStatus.waiting).isOnboard, isFalse);
      expect(studentWith(RideStatus.alighted).isOnboard, isFalse);
      expect(studentWith(RideStatus.handedOver).isOnboard, isFalse);
    });
  });

  group('RideEvent.fromDto', () {
    RideEventDto dto(String type) => RideEventDto.fromJson({
      'id': 1,
      'tenantId': 1,
      'studentId': 1,
      'busId': 1,
      'stopId': 1,
      'type': type,
      'occurredAt': '2026-07-28T12:33:58.674138378',
      'lat': null,
      'lng': null,
      'source': 'MANUAL',
    });

    test('종류와 시각을 변환한다', () {
      final event = RideEvent.fromDto(dto('BOARD'))!;

      expect(event.type, RideEventType.board);
      expect(event.type.label, '승차');
      expect(event.occurredAt.hour, 12);
    });

    test('모르는 종류는 null — 알 수 없는 단계로 학생 상태를 옮기지 않는다', () {
      expect(RideEvent.fromDto(dto('TELEPORT')), isNull);
    });
  });
}
