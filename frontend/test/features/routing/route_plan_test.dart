import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/map/spec/map_view_adapter.dart';
import 'package:school_bus/features/routing/data/dto/route_plan_dto.dart';
import 'package:school_bus/features/routing/domain/route_plan.dart';

void main() {
  group('polyline 파싱 ★', () {
    test('JSON "문자열" 을 한 번 더 풀어서 좌표로 만든다', () {
      // 서버는 배열이 아니라 문자열로 준다.
      final points = RoutePlan.parsePolyline(
        '[[127.0275,37.501],[127.031,37.5045]]',
      );

      expect(points, hasLength(2));
    });

    test('★ [경도, 위도] 순서를 뒤집어 담는다 — 안 뒤집으면 서해에 그려진다', () {
      final points = RoutePlan.parsePolyline('[[127.0275,37.501]]');

      expect(points.first.lat, 37.501, reason: '위도는 두 번째 값이다');
      expect(points.first.lng, 127.0275, reason: '경도는 첫 번째 값이다');
      // 서울 위경도 범위 안에 있어야 한다.
      expect(points.first.lat, inInclusiveRange(37, 38));
      expect(points.first.lng, inInclusiveRange(126, 128));
    });

    test('null·빈 문자열·깨진 JSON 은 빈 목록 — 화면 전체가 죽지 않는다', () {
      expect(RoutePlan.parsePolyline(null), isEmpty);
      expect(RoutePlan.parsePolyline(''), isEmpty);
      expect(RoutePlan.parsePolyline('   '), isEmpty);
      expect(RoutePlan.parsePolyline('not json'), isEmpty);
      expect(RoutePlan.parsePolyline('{"a":1}'), isEmpty, reason: '배열이 아님');
    });

    test('원소 형식이 어긋나면 그 점만 건너뛴다', () {
      final points = RoutePlan.parsePolyline(
        '[[127.0275,37.501],[127.03],["a","b"],[127.031,37.5045]]',
      );

      expect(points, hasLength(2), reason: '길이 부족·문자열 원소는 제외');
      expect(points.last, const GeoPoint(37.5045, 127.031));
    });
  });

  group('RoutePlan.fromDto — 시드 데이터 기준', () {
    /// 3호차 하원 A노선 실제 응답 형태.
    RoutePlanDto seedDto() => RoutePlanDto.fromJson({
      'id': 1,
      'busId': 1,
      'direction': 'DROPOFF',
      'status': 'PUBLISHED',
      'serviceDate': '2026-07-28',
      'totalDistanceM': 1566.0,
      'totalDurationS': 397.0,
      'polyline': '[[127.0355,37.5075],[127.0275,37.501],[127.031,37.5045]]',
      'stops': [
        {
          'seq': 1,
          'studentId': 1,
          'lat': 37.501,
          'lng': 127.0275,
          'etaSeconds': 0,
        },
        {
          'seq': 2,
          'studentId': 3,
          'lat': 37.5045,
          'lng': 127.031,
          'etaSeconds': 397,
        },
      ],
    });

    test('방향·정차·경로가 모두 변환된다', () {
      final plan = RoutePlan.fromDto(seedDto());

      expect(plan.direction, RouteDirection.dropoff);
      expect(plan.direction.label, '하원');
      expect(plan.stops, hasLength(2));
      expect(plan.path, hasLength(3));
      expect(plan.stops.first.point, const GeoPoint(37.501, 127.0275));
    });

    test('모르는 방향 값이 와도 죽지 않는다', () {
      final dto = RoutePlanDto.fromJson({
        ...{
          'id': 1,
          'busId': 1,
          'direction': 'FUTURE_DIRECTION',
          'status': 'PUBLISHED',
          'serviceDate': '2026-07-28',
          'totalDistanceM': 0,
          'totalDurationS': 0,
          'polyline': null,
          'stops': [],
        },
      });

      expect(() => RoutePlan.fromDto(dto), returnsNormally);
    });

    test('polyline 이 없어도 정차 목록은 살아 있다', () {
      final dto = RoutePlanDto.fromJson({
        'id': 1,
        'busId': 1,
        'direction': 'PICKUP',
        'status': 'PUBLISHED',
        'serviceDate': '2026-07-28',
        'totalDistanceM': 100,
        'totalDurationS': 60,
        'polyline': null,
        'stops': [
          {
            'seq': 1,
            'studentId': 1,
            'lat': 37.5,
            'lng': 127.0,
            'etaSeconds': 0,
          },
        ],
      });

      final plan = RoutePlan.fromDto(dto);
      expect(plan.path, isEmpty);
      expect(plan.stops, hasLength(1));
    });
  });

  group('사람이 읽는 표기', () {
    RoutePlan planWith({double distanceM = 0, int durationS = 0}) => RoutePlan(
      id: 1,
      busId: 1,
      direction: RouteDirection.dropoff,
      serviceDate: DateTime(2026, 7, 28),
      totalDistanceM: distanceM,
      totalDuration: Duration(seconds: durationS),
      path: const [],
      stops: const [],
    );

    test('거리 — 1km 미만은 m, 이상은 km', () {
      expect(planWith(distanceM: 860).distanceLabel, '860m');
      expect(planWith(distanceM: 1566).distanceLabel, '1.6km');
    });

    test('소요 시간 — 초를 분으로', () {
      expect(planWith(durationS: 397).durationLabel, '약 7분');
      expect(planWith(durationS: 20).durationLabel, '1분 미만');
      expect(planWith(durationS: 3900).durationLabel, '약 1시간 5분');
    });

    test('ETA — 0초는 "출발"', () {
      RouteStop stop(int seconds) => RouteStop(
        seq: 1,
        studentId: 1,
        point: const GeoPoint(37.5, 127.0),
        eta: Duration(seconds: seconds),
      );

      expect(stop(0).etaLabel, '출발');
      expect(stop(397).etaLabel, '7분 후');
      expect(stop(20).etaLabel, '곧 도착');
    });
  });
}
