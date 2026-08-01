import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/map/spec/map_view_adapter.dart';
import 'package:school_bus/features/drivesession/domain/drive_session.dart';
import 'package:school_bus/features/rideevent/domain/roster_stop_group.dart';
import 'package:school_bus/features/rideevent/domain/roster_student.dart';
import 'package:school_bus/shared/domain/stop_key.dart';

void main() {
  RosterStudent student(
    int id,
    String name, {
    String? location,
    GeoPoint? point,
    RideStatus status = RideStatus.waiting,
  }) => RosterStudent(
    studentId: id,
    name: name,
    location: location,
    point: point,
    status: status,
  );

  const stopA = GeoPoint(37.5010, 127.0275);
  const stopB = GeoPoint(37.5045, 127.0310);

  group('RosterStopGroup.group — 등원', () {
    final pickupRoster = [
      student(1, '김민준', location: '정류장 A', point: stopA),
      student(2, '이서연', location: '정류장 A', point: stopA),
      student(3, '박도윤', location: '정류장 B', point: stopB),
    ];

    test('같은 정류장 학생이 한 그룹으로 묶인다', () {
      final groups = RosterStopGroup.group(
        pickupRoster,
        direction: DriveDirection.pickup,
      );

      expect(groups, hasLength(2));
      expect(groups[0].title, '정류장 A');
      expect(groups[0].students, hasLength(2));
      expect(groups[0].countLabel, '승차 2명');
      expect(groups[1].title, '정류장 B');
      expect(groups[1].countLabel, '승차 1명');
    });

    test('진행률은 학생 행의 완료 판정과 같은 기준을 쓴다', () {
      final groups = RosterStopGroup.group([
        student(1, '김민준', location: '정류장 A', point: stopA),
        student(
          2,
          '이서연',
          location: '정류장 A',
          point: stopA,
          // 등원은 하차까지가 끝이다(인계 단계가 없다).
          status: RideStatus.alighted,
        ),
      ], direction: DriveDirection.pickup);

      expect(groups.single.progressLabel, '1/2명');
      expect(groups.single.isDone, isFalse);
    });

    test('그룹 좌표는 노선과 맞춰 보는 키다', () {
      final groups = RosterStopGroup.group(
        pickupRoster,
        direction: DriveDirection.pickup,
      );

      expect(groups.first.point, stopA);
      expect(groups.first.key, StopKey.of(stopA));
      expect(groups.last.key, StopKey.of(stopB));
    });

    test('전원 처리되면 완료 그룹이 된다', () {
      final groups = RosterStopGroup.group([
        student(
          1,
          '김민준',
          location: '정류장 A',
          point: stopA,
          status: RideStatus.alighted,
        ),
      ], direction: DriveDirection.pickup);

      expect(groups.single.isDone, isTrue);
      // ★ §4 상태 라벨(`승차 완료`·`하차 완료`)을 그룹 요약에 재사용하지 않는다.
      //   하원에서 `하차 완료` 는 인계가 남은 중간 상태를 뜻해 의미가 충돌한다.
      expect(groups.single.collapsedSummary, '처리 완료 · 1명');
    });

    test('★ 접힘 요약이 §4 상태 라벨 어휘를 쓰지 않는다 — 하원', () {
      final groups = RosterStopGroup.group([
        student(
          1,
          '김민준',
          location: '서울 서초구 자택',
          point: stopA,
          status: RideStatus.alighted,
        ),
      ], direction: DriveDirection.dropoff);

      final summary = groups.single.collapsedSummary;
      expect(summary, isNot(contains('하차 완료')));
      expect(summary, isNot(contains('하차 대기')));
      expect(summary, '남은 처리 1명 · 눌러서 펼치기');
    });
  });

  group('RosterStopGroup.group — 하원', () {
    // 시안은 하원도 `정류장 A/B` 로 묶었지만 실제 하차지는 학생마다 다르다.
    // 이 테스트가 그 회귀를 막는다(갭 분석 D1).
    test('하차지가 서로 다르면 묶이지 않는다', () {
      final groups = RosterStopGroup.group([
        student(
          1,
          '김민준',
          location: '서울 서초구 자택',
          point: const GeoPoint(37.4900, 127.0100),
        ),
        student(
          2,
          '이서연',
          location: '서울 서초구 자택2',
          point: const GeoPoint(37.4910, 127.0120),
        ),
        student(
          3,
          '박도윤',
          location: '서울 강남구 자택',
          point: const GeoPoint(37.4930, 127.0150),
        ),
      ], direction: DriveDirection.dropoff);

      expect(groups, hasLength(3), reason: '하차지는 학생별 주소다');
      expect(groups.map((g) => g.title), [
        '서울 서초구 자택',
        '서울 서초구 자택2',
        '서울 강남구 자택',
      ]);
      expect(groups.first.countLabel, '하차 1명');
    });

    test('하차지가 같으면(형제 등) 묶인다', () {
      final groups = RosterStopGroup.group([
        student(1, '김민준', location: '서울 서초구 자택', point: stopA),
        student(4, '김민서', location: '서울 서초구 자택', point: stopA),
      ], direction: DriveDirection.dropoff);

      expect(groups, hasLength(1));
      expect(groups.single.countLabel, '하차 2명');
    });

    test('하원은 하차만으로 끝나지 않는다 — 인계까지 해야 완료', () {
      final groups = RosterStopGroup.group([
        student(
          1,
          '김민준',
          location: '서울 서초구 자택',
          point: stopA,
          status: RideStatus.alighted,
        ),
      ], direction: DriveDirection.dropoff);

      expect(groups.single.isDone, isFalse);
    });
  });

  group('그룹 순번', () {
    test('노선 순번을 주면 그대로 쓴다 — 지도 마커 번호와 맞춘다', () {
      final groups = RosterStopGroup.group(
        [
          // 명단 등장 순서는 정류장 B 가 먼저지만
          student(3, '박도윤', location: '정류장 B', point: stopB),
          student(1, '김민준', location: '정류장 A', point: stopA),
        ],
        direction: DriveDirection.pickup,
        seqByStop: {StopKey.of(stopA): 1, StopKey.of(stopB): 5},
      );

      // 노선 순번대로 A(1) → B(5) 로 재정렬된다.
      expect(groups.map((g) => g.seq), [1, 5]);
      expect(groups.map((g) => g.title), ['정류장 A', '정류장 B']);
    });

    test('노선이 없으면 명단 등장 순으로 1부터 매긴다', () {
      final groups = RosterStopGroup.group([
        student(3, '박도윤', location: '정류장 B', point: stopB),
        student(1, '김민준', location: '정류장 A', point: stopA),
      ], direction: DriveDirection.pickup);

      expect(groups.map((g) => g.seq), [1, 2]);
      expect(groups.first.title, '정류장 B', reason: '등장 순서를 보존한다');
    });

    test('노선에 없는 정차는 있는 정차 뒤로 밀린다', () {
      final groups = RosterStopGroup.group(
        [
          student(3, '박도윤', location: '정류장 B', point: stopB),
          student(1, '김민준', location: '정류장 A', point: stopA),
        ],
        direction: DriveDirection.pickup,
        seqByStop: {StopKey.of(stopA): 2},
      );

      expect(groups.first.title, '정류장 A');
      expect(groups.last.title, '정류장 B');
    });

    // ★ 회귀 방지: 예전에는 폴백 번호가 목록 위치(index+1)라, 노선이 준 2번과
    //   그 뒤에 붙은 정차의 2번이 겹쳤다. 그러면 지도에는 ②가 하나인데 명단에는
    //   ②가 둘이 되어 기사가 엉뚱한 곳에서 아이를 태운다.
    test('★ 노선에 없는 정차가 노선 순번과 같은 번호를 갖지 않는다', () {
      final groups = RosterStopGroup.group(
        [
          student(3, '박도윤', location: '정류장 B', point: stopB),
          student(1, '김민준', location: '정류장 A', point: stopA),
        ],
        direction: DriveDirection.pickup,
        seqByStop: {StopKey.of(stopA): 2},
      );

      expect(groups.map((g) => g.seq), [2, 3]);
      expect(
        groups.map((g) => g.seq).toSet(),
        hasLength(groups.length),
        reason: '순번은 절대 중복되지 않는다',
      );
    });

    test('★ 좌표 없는 학생이 섞여도 순번이 겹치지 않는다', () {
      final groups = RosterStopGroup.group(
        [
          student(1, '김민준', location: '정류장 A', point: stopA),
          // 정류장 미지정 — 노선에도 없다
          student(9, '학생09'),
          student(3, '박도윤', location: '정류장 B', point: stopB),
        ],
        direction: DriveDirection.pickup,
        seqByStop: {StopKey.of(stopA): 1, StopKey.of(stopB): 2},
      );

      expect(groups.map((g) => g.seq), [1, 2, 3]);
      expect(groups.last.students.single.name, '학생09');
    });
  });

  group('좌표가 없는 학생', () {
    test('서로 묶이지 않고 각자 한 그룹이 된다', () {
      final groups = RosterStopGroup.group([
        student(1, '김민준'),
        student(2, '이서연'),
      ], direction: DriveDirection.pickup);

      expect(groups, hasLength(2), reason: '묶을 근거(좌표)가 없다');
      expect(groups.map((g) => g.title), ['1번 정차', '2번 정차']);
    });
  });

  test('빈 명단은 빈 목록', () {
    expect(
      RosterStopGroup.group(const [], direction: DriveDirection.pickup),
      isEmpty,
    );
  });
}
