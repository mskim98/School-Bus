import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../spec/map_view_adapter.dart';

/// `flutter_map`(OSM 타일) 기반 구현.
///
/// 이 파일이 지도 라이브러리를 아는 **유일한 곳**이다. 화면은 [MapViewAdapter] 와
/// [GeoPoint] 만 쓰므로, 지도를 바꿔도 이 파일만 갈아끼우면 된다(컨벤션 §5).
class FlutterMapAdapter implements MapViewAdapter {
  const FlutterMapAdapter();

  /// 좌표가 하나도 없을 때 보여줄 기본 위치(한빛학원 근처).
  static const _fallbackCenter = LatLng(37.5075, 127.0355);

  @override
  Widget build({
    List<MapMarkerSpec> markers = const [],
    List<MapRouteSpec> routes = const [],
  }) {
    return _FlutterMapView(markers: markers, routes: routes);
  }

  static LatLng _toLatLng(GeoPoint p) => LatLng(p.lat, p.lng);
}

class _FlutterMapView extends StatelessWidget {
  const _FlutterMapView({required this.markers, required this.routes});

  final List<MapMarkerSpec> markers;
  final List<MapRouteSpec> routes;

  /// 마커·경로가 모두 화면에 들어오도록 맞춘다.
  ///
  /// 시드 데이터 기준 경로가 대각선 1.2km 정도로 좁아, 여백 없이 맞추면 마커가
  /// 가장자리에 붙는다. 그래서 패딩을 넉넉히 준다.
  CameraFit? _fit() {
    final points = <LatLng>[
      for (final m in markers) FlutterMapAdapter._toLatLng(m.point),
      for (final r in routes)
        for (final p in r.points) FlutterMapAdapter._toLatLng(p),
    ];
    if (points.isEmpty) return null;

    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.all(48),
      // 점이 하나뿐이면 bounds 가 한 점이라 무한대로 확대된다.
      maxZoom: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fit = _fit();

    return FlutterMap(
      options: MapOptions(
        initialCenter: FlutterMapAdapter._fallbackCenter,
        initialZoom: 14,
        initialCameraFit: fit,
        interactionOptions: const InteractionOptions(
          // 회전은 운전 중 오조작으로 지도가 돌아가는 사고만 만든다.
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // OSM 타일 사용 정책상 앱 식별자를 보내야 한다.
          userAgentPackageName: 'com.schoolbus.school_bus',
        ),
        if (routes.isNotEmpty)
          PolylineLayer(
            polylines: [
              for (final r in routes)
                if (r.points.length >= 2)
                  Polyline(
                    points: r.points.map(FlutterMapAdapter._toLatLng).toList(),
                    strokeWidth: 5,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ],
          ),
        if (markers.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final m in markers)
                Marker(
                  point: FlutterMapAdapter._toLatLng(m.point),
                  width: 40,
                  height: 40,
                  child: _MarkerPin(spec: m),
                ),
            ],
          ),
      ],
    );
  }
}

class _MarkerPin extends StatelessWidget {
  const _MarkerPin({required this.spec});

  final MapMarkerSpec spec;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 색만으로 구분하지 않는다 — 직사광선 아래서도 읽히도록 아이콘·숫자를 함께 쓴다.
    final (
      Color background,
      Color foreground,
      Widget content,
    ) = switch (spec.kind) {
      MapMarkerKind.bus => (
        scheme.primary,
        scheme.onPrimary,
        Icon(Icons.directions_bus, size: 20, color: scheme.onPrimary),
      ),
      MapMarkerKind.depot => (
        scheme.tertiary,
        scheme.onTertiary,
        Icon(Icons.school, size: 18, color: scheme.onTertiary),
      ),
      MapMarkerKind.stop => (
        scheme.secondary,
        scheme.onSecondary,
        Text(
          spec.label ?? '',
          style: TextStyle(
            color: scheme.onSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      MapMarkerKind.visitedStop => (
        scheme.surfaceContainerHighest,
        scheme.outline,
        Icon(Icons.check, size: 18, color: scheme.outline),
      ),
    };

    final pin = Container(
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.surface, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: content,
      ),
    );

    if (spec.onTap == null) return pin;
    return GestureDetector(onTap: spec.onTap, child: pin);
  }
}

final mapViewAdapterProvider = Provider<MapViewAdapter>(
  (ref) => const FlutterMapAdapter(),
);
