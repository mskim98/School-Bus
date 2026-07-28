import '../../map/spec/map_view_adapter.dart';
import 'location_source.dart';
import 'location_source_kind.dart';

/// [LocationSourceKind] → [LocationSource] 를 만들어 주는 포트.
///
/// 상태 계층이 `MockLocationSource`·`GpsLocationSource` 같은 구현 타입을 직접 `new`
/// 하지 않게 하려고 둔다(컨벤션 §5, 검사 C-5). 테스트는 이 포트를 가짜로 갈아끼워
/// 실제 GPS·타이머 없이 전송 로직만 검증한다.
abstract interface class LocationSourceFactory {
  /// [mockPath] 는 [LocationSourceKind.mock] 일 때만 쓰인다 — Mock 이 따라갈 노선 좌표다.
  LocationSource create(
    LocationSourceKind kind, {
    required List<GeoPoint> mockPath,
  });
}
