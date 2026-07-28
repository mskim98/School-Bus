import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 지도 위 한 점. 지도 라이브러리 타입을 쓰지 않는 **중립 모델**이다 —
/// 화면이 `LatLng`(flutter_map) 같은 구현 타입을 직접 다루면 지도 교체가 불가능해진다.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// 마커 종류 — 색·모양은 어댑터 구현이 정한다.
enum MapMarkerKind {
  /// 버스 현재 위치
  bus,

  /// 정차 지점(순번 표시)
  stop,

  /// 이미 지난 정차
  visitedStop,

  /// 학원(출발·도착지)
  depot,
}

class MapMarkerSpec {
  const MapMarkerSpec({
    required this.point,
    required this.kind,
    this.label,
    this.onTap,
  });

  final GeoPoint point;
  final MapMarkerKind kind;

  /// 마커 위에 표시할 짧은 문자열(정차 순번 등)
  final String? label;
  final VoidCallback? onTap;
}

class MapRouteSpec {
  const MapRouteSpec({required this.points});

  /// 경로를 이루는 좌표들. 2개 미만이면 그리지 않는다.
  final List<GeoPoint> points;
}

/// 지도 포트.
///
/// 포트로 둔 이유(컨벤션 §5): 지금은 `flutter_map`(OSM)을 쓰지만, `flutter_naver_map` 이
/// Web 을 지원하게 되거나 요구가 바뀌면 교체할 수 있어야 한다. 화면은 이 인터페이스와
/// [GeoPoint] 만 알고, 구현체는 `core/map/impl/` 에 둔다.
abstract interface class MapViewAdapter {
  /// 마커·경로를 얹은 지도 위젯을 만든다.
  ///
  /// [markers] 와 [routes] 가 모두 비면 어댑터가 기본 위치를 보여준다.
  /// 좌표가 있으면 **전부 화면에 들어오도록 자동으로 맞춘다**(수동 줌 계산을 화면에 두지 않는다).
  Widget build({List<MapMarkerSpec> markers, List<MapRouteSpec> routes});
}

/// ⚠️ `bootstrap()` 에서 override 해야 하는 provider.
///
/// **provider 선언이 구현체 파일이 아니라 여기 있는 이유**(컨벤션 §5) —
/// 구현체 파일에 두면 소비자가 `impl/...` 을 import 하게 되고, 그러면 구현을 갈아끼울 때
/// 호출부를 전부 고쳐야 한다. 지도는 교체 후보(네이버·구글)가 실제로 있는 포트라
/// 이 규칙이 특히 중요하다 — 지금 구조에서만 지도 교체가 화면 수정 없이 끝난다.
final mapViewAdapterProvider = Provider<MapViewAdapter>(
  (ref) => throw UnimplementedError(
    'mapViewAdapterProvider 를 bootstrap() 에서 override 해야 합니다',
  ),
);
