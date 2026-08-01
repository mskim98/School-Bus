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

  /// 다음에 갈 정차(순번 표시) — 채운 원으로 가장 눈에 띈다
  stop,

  /// 그 뒤에 남은 정차 — 테두리만 있는 원. 다음 정차와 **모양으로** 구분한다
  /// (§5.3). 색만 다르게 하면 직사광선 아래서 둘이 같아 보인다.
  upcomingStop,

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

/// 지도 카메라 제어. 화면이 이 인터페이스만 쓰고 flutter_map 을 모르게 한다.
///
/// 별도 인터페이스로 뺀 이유: 카메라는 **위젯을 다시 그리지 않고** 움직여야 하는
/// 명령형 동작이라([build] 인자로는 표현할 수 없다), 지도 라이브러리마다 컨트롤러
/// 타입이 다르다. 여기를 통과시키지 않으면 화면이 `MapController`(flutter_map)를
/// 직접 들게 되고, 그 순간 지도 교체가 다시 불가능해진다(컨벤션 §5).
abstract interface class MapCameraController {
  /// 한 점으로 이동. [zoom] 이 null 이면 현재 배율을 유지한다.
  void moveTo(GeoPoint point, {double? zoom});

  /// 현재 그려진 마커·경로가 전부 들어오게 맞춘다.
  void fitAll();

  /// 현재 중심을 유지한 채 배율만 [delta] 만큼 바꾼다(양수 확대, 음수 축소).
  ///
  /// 화면에 확대 버튼을 두려면 필요하다 — 손가락 두 개(`pinch`)나 휠은 기기에
  /// 따라 아예 못 쓰는 경우가 있고(장갑 낀 손, 마우스 없는 태블릿), 운전석에서
  /// 두 손가락 조작을 요구할 수는 없다.
  void zoomBy(double delta);
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
  ///
  /// [onReady] 는 지도가 준비되면 카메라 손잡이를 한 번 넘겨준다 — `내 위치`·
  /// `전체 경로` 버튼처럼 화면이 카메라를 직접 움직여야 할 때만 쓴다.
  /// **선택 인자**라 카메라가 필요 없는 화면(관제 지도 등)은 지금 그대로 둔다.
  /// [obscured] 는 **다른 위젯이 지도를 덮고 있는 넓이**다.
  ///
  /// 기사 노선 화면은 지도를 화면 전체에 깔고 그 위에 정차 시트(아래 55%)와 다음
  /// 정차 카드(위)를 얹는다. 이때 좌표를 지도 한가운데에 맞추면 **눈에는 시트
  /// 밑에 깔린 것으로 보인다** — 지도의 중앙과 사람이 보는 영역의 중앙이 다르기
  /// 때문이다. 가려진 넓이를 알려주면 그만큼 피해서 맞춘다.
  Widget build({
    List<MapMarkerSpec> markers,
    List<MapRouteSpec> routes,
    void Function(MapCameraController)? onReady,
    EdgeInsets obscured,
  });
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
