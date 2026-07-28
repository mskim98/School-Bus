import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/location/impl/mock_location_source.dart';
import 'package:school_bus/core/location/spec/location_source.dart';
import 'package:school_bus/core/map/spec/map_view_adapter.dart';

/// 시드 노선과 비슷한 축척(강남 일대, 한 변 400m 안팎)의 짧은 경로.
const _path = [
  GeoPoint(37.5010, 127.0275),
  GeoPoint(37.5045, 127.0310),
  GeoPoint(37.5075, 127.0355),
];

void main() {
  group('MockLocationSource — 경로를 따라 이동한다', () {
    test('첫 read 는 출발점을 준다 — 켜자마자 엉뚱한 곳에서 시작하지 않는다', () async {
      final source = MockLocationSource(_path);

      expect(await source.read(), _path.first);
    });

    test('read 를 반복하면 설정한 거리만큼 전진한다', () async {
      // 한 번에 100m — 구간 길이보다 짧아 보간이 실제로 일어난다.
      final source = MockLocationSource(_path, metersPerRead: 100);

      final first = await source.read();
      final second = await source.read();

      final moved = MockLocationSource.distanceMeters(first, second);
      expect(moved, closeTo(100, 5), reason: '한 tick 이동 거리');
      expect(second, isNot(_path.first));
    });

    test('보간된 점은 경로 선분 위에 있다 — 지도 밖으로 튀지 않는다', () async {
      final source = MockLocationSource(_path, metersPerRead: 100);
      await source.read(); // 출발점 소비

      final point = await source.read();

      // 첫 구간(0→1) 안에 있어야 한다.
      expect(point.lat, inInclusiveRange(_path[0].lat, _path[1].lat));
      expect(point.lng, inInclusiveRange(_path[0].lng, _path[1].lng));
    });

    test('★ 종점에 닿으면 되돌아온다 — 한 방향으로만 가면 시연이 종점에서 멈춘다', () async {
      // 한 번에 아주 크게 움직여 두 번째 read 에서 종점에 닿게 한다.
      final source = MockLocationSource(_path, metersPerRead: 100000);

      expect(await source.read(), _path.first);
      expect(await source.read(), _path.last, reason: '종점 도달');
      expect(await source.read(), _path.first, reason: '방향이 뒤집혀 되돌아온다');
    });

    test('점이 하나뿐인 경로는 같은 좌표를 반복한다 — 0으로 나누지 않는다', () async {
      final source = MockLocationSource(const [GeoPoint(37.5, 127.0)]);

      expect(await source.read(), const GeoPoint(37.5, 127.0));
      expect(await source.read(), const GeoPoint(37.5, 127.0));
    });

    test('같은 좌표가 연달아 있어도(구간 길이 0) 터지지 않는다', () async {
      final source = MockLocationSource(const [
        GeoPoint(37.5, 127.0),
        GeoPoint(37.5, 127.0),
        GeoPoint(37.51, 127.01),
      ], metersPerRead: 50);

      expect(() async => source.read(), returnsNormally);
      expect(await source.read(), isA<GeoPoint>());
    });

    test('★ 경로가 비면 예외 — "노선이 없다"를 조용히 좌표 0,0 으로 덮지 않는다', () async {
      final source = MockLocationSource(const []);

      await expectLater(
        source.read(),
        throwsA(isA<LocationUnavailableException>()),
      );
    });
  });

  group('거리 계산', () {
    test('같은 점 사이 거리는 0이다', () {
      expect(
        MockLocationSource.distanceMeters(_path.first, _path.first),
        closeTo(0, 0.001),
      );
    });

    test('위도 0.001도 ≈ 111m', () {
      final distance = MockLocationSource.distanceMeters(
        const GeoPoint(37.5, 127.0),
        const GeoPoint(37.501, 127.0),
      );

      expect(distance, closeTo(111, 2));
    });
  });
}
