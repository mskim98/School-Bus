import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// ⚠️ `bootstrap()` 에서 override 해야 하는 provider.
///
/// **provider 선언이 구현체 파일이 아니라 여기 있는 이유**(컨벤션 §5) —
/// 구현체 파일에 두면 소비자가 `impl/...` 을 import 하게 되고, 그러면 구현을 갈아끼울 때
/// 호출부를 전부 고쳐야 한다. 포트를 만든 목적 자체가 사라진다.
final locationSourceFactoryProvider = Provider<LocationSourceFactory>(
  (ref) => throw UnimplementedError(
    'locationSourceFactoryProvider 를 bootstrap() 에서 override 해야 합니다',
  ),
);
