import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/location/data/dto/bus_location_dto.dart';
import 'package:school_bus/features/location/data/dto/bus_summary_dto.dart';
import 'package:school_bus/features/location/domain/monitored_bus.dart';

BusSummaryDto _bus(int id, String name, {String? driverName}) =>
    BusSummaryDto(id: id, name: name, driverName: driverName);

BusLocationDto _location(
  int busId, {
  String name = '',
  double lat = 37.5075,
  double lng = 127.0355,
  String recordedAt = '2026-07-28T12:34:26.199274169',
  String origin = 'GPS',
}) => BusLocationDto(
  busId: busId,
  busName: name,
  lat: lat,
  lng: lng,
  recordedAt: recordedAt,
  origin: origin,
);

void main() {
  final now = DateTime(2026, 7, 28, 21, 0, 0);

  group('BusLocationDto.fromJson — 실측 응답 기준', () {
    test('시드 응답을 그대로 읽는다', () {
      final dto = BusLocationDto.fromJson(const {
        'busId': 1,
        'busName': '3호차',
        'lat': 37.5075,
        'lng': 127.0355,
        'recordedAt': '2026-07-28T12:34:26.199274169',
        'origin': 'MOCK',
      });

      expect(dto.busId, 1);
      expect(dto.busName, '3호차');
      expect(dto.lat, 37.5075);
      expect(dto.origin, 'MOCK');
      // 타임존이 없는 문자열이라 파싱하지 않고 그대로 들고 있는다.
      expect(dto.recordedAt, '2026-07-28T12:34:26.199274169');
    });

    test('lat/lng 가 정수로 와도 double 로 읽는다', () {
      final dto = BusLocationDto.fromJson(const {
        'busId': 2,
        'busName': '1호차',
        'lat': 37,
        'lng': 127,
        'recordedAt': '',
        'origin': 'GPS',
      });

      expect(dto.lat, 37.0);
      expect(dto.lng, 127.0);
    });
  });

  group('LocationOrigin', () {
    test('GPS/MOCK 을 읽는다', () {
      expect(LocationOrigin.fromWire('GPS'), LocationOrigin.gps);
      expect(LocationOrigin.fromWire('MOCK'), LocationOrigin.mock);
    });

    test('모르는 값·null 은 unknown — 서버가 값을 늘려도 화면이 죽지 않는다', () {
      expect(LocationOrigin.fromWire('SATELLITE'), LocationOrigin.unknown);
      expect(LocationOrigin.fromWire(null), LocationOrigin.unknown);
    });
  });

  group('MonitoredBus.merge ★ — 두 응답을 합쳐야 관제 화면이 된다', () {
    test('★ 위치 보고가 없는 버스도 목록에 남는다 — 배열에서 빠진다고 사라지면 안 된다', () {
      final merged = MonitoredBus.merge(
        buses: [
          _bus(1, '3호차', driverName: '박기사'),
          _bus(2, '1호차'),
        ],
        locations: [_location(1)],
        observedAt: now,
      );

      expect(merged, hasLength(2));
      expect(merged[0].hasPosition, isTrue);
      expect(merged[1].hasPosition, isFalse, reason: '1호차는 한 번도 보고한 적이 없다');
      expect(merged[1].name, '1호차');
    });

    test('버스 목록에 없는데 위치만 온 버스는 뒤에 덧붙인다', () {
      final merged = MonitoredBus.merge(
        buses: [_bus(1, '3호차')],
        locations: [
          _location(1),
          _location(9, name: '9호차'),
        ],
        observedAt: now,
      );

      expect(merged, hasLength(2));
      expect(merged.last.busId, 9);
      expect(merged.last.name, '9호차');
    });

    test('★ 같은 recordedAt 이면 받은 시각을 물려받는다 — 멈춘 버스가 "방금"으로 안 보이게', () {
      final first = MonitoredBus.merge(
        buses: [_bus(1, '3호차')],
        locations: [_location(1, recordedAt: 'T1')],
        observedAt: now,
      );

      // 30초 뒤 폴링했는데 서버 값이 그대로다.
      final later = now.add(const Duration(seconds: 30));
      final second = MonitoredBus.merge(
        buses: [_bus(1, '3호차')],
        locations: [_location(1, recordedAt: 'T1')],
        observedAt: later,
        previous: first,
      );

      expect(second.single.position!.observedAt, now, reason: '처음 받은 시각 유지');
      expect(second.single.staleness(later), const Duration(seconds: 30));
    });

    test('recordedAt 이 바뀌면 받은 시각을 갱신한다', () {
      final first = MonitoredBus.merge(
        buses: [_bus(1, '3호차')],
        locations: [_location(1, recordedAt: 'T1')],
        observedAt: now,
      );

      final later = now.add(const Duration(seconds: 30));
      final second = MonitoredBus.merge(
        buses: [_bus(1, '3호차')],
        locations: [_location(1, recordedAt: 'T2')],
        observedAt: later,
        previous: first,
      );

      expect(second.single.position!.observedAt, later);
      expect(second.single.staleness(later), Duration.zero);
    });

    test('★ 이번 응답에서 빠진 버스는 이전 좌표를 유지한다 — 지도가 깜빡이지 않게', () {
      final first = MonitoredBus.merge(
        buses: [_bus(1, '3호차')],
        locations: [_location(1, lat: 37.5, lng: 127.0)],
        observedAt: now,
      );

      final second = MonitoredBus.merge(
        buses: [_bus(1, '3호차')],
        locations: const [], // 서버가 이번엔 아무 것도 안 줬다
        observedAt: now.add(const Duration(seconds: 3)),
        previous: first,
      );

      expect(second.single.hasPosition, isTrue);
      expect(second.single.position!.point.lat, 37.5);
    });

    test('빈 응답 둘은 빈 목록 — 에러가 아니다', () {
      expect(
        MonitoredBus.merge(
          buses: const [],
          locations: const [],
          observedAt: now,
        ),
        isEmpty,
      );
    });

    test('staleness 는 위치가 없으면 null 이다', () {
      final merged = MonitoredBus.merge(
        buses: [_bus(2, '1호차')],
        locations: const [],
        observedAt: now,
      );

      expect(merged.single.staleness(now), isNull);
    });
  });
}
