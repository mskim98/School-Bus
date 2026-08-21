import '../../../core/location/spec/location_source_kind.dart';
import '../../../core/map/spec/map_view_adapter.dart';
import '../data/dto/bus_location_dto.dart';
import '../data/dto/bus_summary_dto.dart';

/// 좌표 출처. 서버가 `GPS` / `MOCK` 두 값만 준다.
///
/// **읽기·쓰기 양쪽이 쓰는 하나의 표현이다.** 관제 화면은 서버 응답을
/// [fromWire] 로 읽고, 기사 앱은 자기 좌표 출처를 [fromSourceKind] 로 옮겨
/// [wireName] 을 `POST /api/locations/bus` 본문에 실어 보낸다. 전송 문자열이
/// 여기 말고 다른 곳에 리터럴로 나타나면 두 표기가 어긋난다.
enum LocationOrigin {
  gps('GPS', '단말'),
  mock('MOCK', '시뮬레이터'),

  /// 서버가 새 값을 추가했을 때 화면이 죽지 않도록 두는 자리.
  /// **보고에는 쓰지 않는다** — [fromSourceKind] 는 이 값을 돌려주지 않는다.
  unknown('', '알 수 없음');

  const LocationOrigin(this.wireName, this.label);

  /// 서버 enum `LocationOrigin` 과 글자까지 일치해야 하는 전송·수신 표기.
  final String wireName;
  final String label;

  static LocationOrigin fromWire(String? value) {
    for (final origin in LocationOrigin.values) {
      if (origin.wireName == value) return origin;
    }
    return LocationOrigin.unknown;
  }

  /// 기사 앱이 지금 쓰는 좌표 소스를 서버가 기록할 출처로 옮긴다.
  ///
  /// 이 변환이 없으면 Mock 좌표도 서버에 `GPS` 로 남아 관제 화면의 "출처" 표기가
  /// 실제와 달라진다(서버는 `origin` 이 없는 요청을 `GPS` 로 처리한다).
  static LocationOrigin fromSourceKind(LocationSourceKind kind) =>
      switch (kind) {
        LocationSourceKind.mock => LocationOrigin.mock,
        LocationSourceKind.gps => LocationOrigin.gps,
      };
}

/// 버스가 마지막으로 알려준 위치.
class BusPosition {
  const BusPosition({
    required this.point,
    required this.origin,
    required this.recordedAt,
    required this.observedAt,
  });

  final GeoPoint point;
  final LocationOrigin origin;

  /// 서버가 기록한 시각 문자열. **타임존이 없어 절대 시각으로 쓸 수 없다**
  /// (`BusLocationDto.recordedAt` 주석 참조) — 값이 바뀌었는지 비교하는 용도다.
  final String recordedAt;

  /// 이 좌표를 **클라이언트가 처음 받은 시각**. 신선도("N초 전")를 여기서 잰다.
  ///
  /// 서버 시각을 안 쓰는 이유: 서버·브라우저의 타임존이 달라 서버 값으로 계산하면
  /// 항상 몇 시간씩 어긋난 값이 나온다. 클라이언트 시계끼리 비교하면 어긋날 일이 없다.
  final DateTime observedAt;

  static BusPosition fromDto(
    BusLocationDto dto, {
    required DateTime observedAt,
  }) {
    return BusPosition(
      point: GeoPoint(dto.lat, dto.lng),
      origin: LocationOrigin.fromWire(dto.origin),
      recordedAt: dto.recordedAt,
      observedAt: observedAt,
    );
  }
}

/// 관제 지도가 쓰는 버스 한 대.
///
/// DTO 를 그대로 못 쓰는 이유(컨벤션 §4): **응답 두 개를 합쳐야 완성된다.**
/// `GET /api/buses`(전체 목록)와 `GET /api/locations/buses`(위치가 있는 것만)를
/// 합쳐야 "위치를 아직 모르는 버스"를 화면에서 구분할 수 있다(계획서 §3.6).
class MonitoredBus {
  const MonitoredBus({
    required this.busId,
    required this.name,
    this.plateNumber,
    this.driverName,
    this.position,
  });

  final int busId;
  final String name;
  final String? plateNumber;

  /// 기사가 배차되지 않은 버스는 null 이다.
  final String? driverName;

  /// null 이면 **위치 보고 이력이 없다**(버스가 없는 것과 다르다).
  final BusPosition? position;

  bool get hasPosition => position != null;

  /// 마지막 좌표를 받은 지 얼마나 지났는지. 위치가 없으면 null.
  Duration? staleness(DateTime now) {
    final observedAt = position?.observedAt;
    return observedAt == null ? null : now.difference(observedAt);
  }

  MonitoredBus copyWith({BusPosition? position}) => MonitoredBus(
    busId: busId,
    name: name,
    plateNumber: plateNumber,
    driverName: driverName,
    position: position ?? this.position,
  );

  /// 버스 목록과 위치 목록을 합친다.
  ///
  /// - 목록에 있고 위치가 없는 버스 → [position] 이 null 인 채로 남긴다(빠뜨리지 않는다)
  /// - 위치만 있고 목록에 없는 버스 → 뒤에 덧붙인다.
  ///   버스 목록 조회가 실패했을 때도 지도가 비지 않게 하기 위함이다
  /// - [previous] 에 같은 좌표(같은 `recordedAt`)가 이미 있으면 **받은 시각을 그대로
  ///   물려준다** — 안 그러면 폴링할 때마다 "방금 갱신"으로 보여 멈춘 버스를 못 알아챈다
  static List<MonitoredBus> merge({
    required List<BusSummaryDto> buses,
    required List<BusLocationDto> locations,
    required DateTime observedAt,
    List<MonitoredBus> previous = const [],
  }) {
    final previousById = {for (final bus in previous) bus.busId: bus};
    final locationById = {for (final loc in locations) loc.busId: loc};

    BusPosition? positionOf(int busId) {
      final dto = locationById[busId];
      if (dto == null) {
        // 이번 응답에 없는 버스 — 이전에 받아둔 좌표가 있으면 유지한다(깜빡임 방지).
        return previousById[busId]?.position;
      }
      final before = previousById[busId]?.position;
      final unchanged = before != null && before.recordedAt == dto.recordedAt;
      return BusPosition.fromDto(
        dto,
        observedAt: unchanged ? before.observedAt : observedAt,
      );
    }

    final merged = [
      for (final bus in buses)
        MonitoredBus(
          busId: bus.id,
          name: bus.name,
          plateNumber: bus.plateNumber,
          driverName: bus.driverName,
          position: positionOf(bus.id),
        ),
    ];

    final knownIds = {for (final bus in buses) bus.id};
    for (final loc in locations) {
      if (knownIds.contains(loc.busId)) continue;
      merged.add(
        MonitoredBus(
          busId: loc.busId,
          name: loc.busName,
          position: positionOf(loc.busId),
        ),
      );
    }
    return List.unmodifiable(merged);
  }
}
