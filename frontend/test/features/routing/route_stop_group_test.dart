import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/map/spec/map_view_adapter.dart';
import 'package:school_bus/features/routing/domain/route_plan.dart';
import 'package:school_bus/features/routing/domain/route_stop_group.dart';

void main() {
  RouteStop stop(int seq, int studentId, double lat, double lng, int eta) =>
      RouteStop(
        seq: seq,
        studentId: studentId,
        point: GeoPoint(lat, lng),
        eta: Duration(seconds: eta),
      );

  group('RouteStopGroup.group — 학생 단위 stops[] 를 정차 단위로', () {
    // 2026-07-29 `GET /api/route-plans/driver/1` 실측값 그대로다.
    // 정차는 2곳인데 서버는 학생 수만큼 6줄을 준다.
    final measured = [
      stop(1, 5, 37.5010, 127.0275, 0),
      stop(2, 4, 37.5010, 127.0275, 0),
      stop(3, 2, 37.5010, 127.0275, 0),
      stop(4, 1, 37.5010, 127.0275, 0),
      stop(5, 6, 37.5045, 127.0310, 192),
      stop(6, 3, 37.5045, 127.0310, 192),
    ];

    test('같은 좌표 6줄이 정차 2곳으로 묶인다', () {
      final groups = RouteStopGroup.group(measured);

      expect(groups, hasLength(2), reason: '마커가 겹쳐 찍히던 원인이 이것이다');
      expect(groups[0].studentCount, 4);
      expect(groups[1].studentCount, 2);
    });

    // ★ 서버 `seq` 는 정차 번호가 아니라 **학생 번호**다. 최소 seq 를 그대로
    //   배지에 쓰면 번호가 건너뛴다(2026-07-29 등원 실측: 정차 2곳에 seq 1·3).
    //   기사가 ①③ 을 보고 "②는 어디 갔나"를 찾게 된다.
    test('★ 정차 번호는 1부터 이어진다 — 서버 seq 를 그대로 쓰지 않는다', () {
      final groups = RouteStopGroup.group(measured);

      expect(groups.map((g) => g.seq), [1, 2]);
      expect(groups.map((g) => g.eta.inSeconds), [0, 192], reason: 'ETA 는 최소값');
    });

    test('★ 실측 등원(정차 2곳, 서버 seq 1·3)도 ①② 로 나온다', () {
      final groups = RouteStopGroup.group([
        stop(1, 2, 37.5010, 127.0275, 0),
        stop(2, 1, 37.5010, 127.0275, 0),
        stop(3, 3, 37.5045, 127.0310, 222),
      ]);

      expect(groups.map((g) => g.seq), [1, 2]);
      expect(groups.map((g) => g.studentCount), [2, 1]);
    });

    test('방문 순서는 서버 seq 를 따른다 — 입력 순서를 믿지 않는다', () {
      final groups = RouteStopGroup.group(measured.reversed.toList());

      expect(groups.map((g) => g.seq), [1, 2]);
      expect(groups.first.studentIds, [5, 4, 2, 1], reason: '그룹 안도 seq 순');
      expect(groups.first.eta.inSeconds, 0, reason: '먼저 가는 정차가 앞이다');
    });

    test('이름을 모르면 순번으로 부른다 — 정류장 이름을 지어내지 않는다', () {
      final groups = RouteStopGroup.group(measured);

      expect(groups[0].title, '1번 정차');
      expect(groups[1].title, '2번 정차');
      expect(groups[0].subtitle, '4명');
      expect(groups[0].etaLabel, '출발', reason: 'etaSeconds 0 은 출발지다(§7-8)');
      expect(groups[1].etaLabel, '3분 후');
    });

    test('운행을 시작해 명단이 붙으면 제목이 실제 이름으로 바뀐다', () {
      final group = RouteStopGroup.group(
        measured,
      ).first.withRoster(label: '정류장 A', studentNames: ['김민준', '이서연']);

      expect(group.title, '정류장 A');
      expect(group.subtitle, '김민준 외 1명');
    });

    test('하원처럼 좌표가 전부 다르면 학생 수만큼 그룹이 된다', () {
      final groups = RouteStopGroup.group([
        stop(1, 1, 37.4900, 127.0100, 0),
        stop(2, 2, 37.4910, 127.0120, 120),
        stop(3, 3, 37.4930, 127.0150, 300),
      ]);

      expect(groups, hasLength(3));
      expect(groups.map((g) => g.subtitle), everyElement('1명'));
    });

    test('빈 stops[] 는 빈 목록', () {
      expect(RouteStopGroup.group(const []), isEmpty);
    });
  });
}
