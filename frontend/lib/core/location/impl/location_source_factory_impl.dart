import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../map/spec/map_view_adapter.dart';
import '../spec/location_source.dart';
import '../spec/location_source_factory.dart';
import '../spec/location_source_kind.dart';
import 'gps_location_source.dart';
import 'mock_location_source.dart';

/// 구현체 두 개를 아는 **유일한 곳**. 새 좌표 출처가 생기면 여기에 한 갈래만 늘린다.
class LocationSourceFactoryImpl implements LocationSourceFactory {
  const LocationSourceFactoryImpl();

  @override
  LocationSource create(
    LocationSourceKind kind, {
    required List<GeoPoint> mockPath,
  }) => switch (kind) {
    LocationSourceKind.mock => MockLocationSource(mockPath),
    LocationSourceKind.gps => const GpsLocationSource(),
  };
}

final locationSourceFactoryProvider = Provider<LocationSourceFactory>(
  (ref) => const LocationSourceFactoryImpl(),
);
