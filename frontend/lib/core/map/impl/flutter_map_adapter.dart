import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
                    // §5.3 이 지정한 굵기. 타일 위에서 5 는 도로선과 섞여
                    // 어느 쪽이 우리 경로인지 잠깐 봐서는 안 읽힌다.
                    strokeWidth: 9,
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // 색만으로 구분하지 않는다 — 직사광선 아래서도 읽히도록 아이콘·숫자를 함께 쓴다.
    final (
      Color background,
      Color foreground,
      Widget content,
    ) = switch (spec.kind) {
      // §5.3 이 정한 역할색만 쓴다. `secondary`·`tertiary` 는 시드에서 자동
      // 파생될 뿐 디자인 시스템 §1 이 정의한 역할이 아니라, 그 색이 무슨 뜻인지
      // 아무도 모른다 — 지도는 화면에서 가장 오래 보는 곳이라 특히 그렇다.
      MapMarkerKind.bus => (
        scheme.onSurface,
        scheme.surface,
        Icon(Icons.directions_bus, size: 20, color: scheme.surface),
      ),
      MapMarkerKind.depot => (
        scheme.onSurface,
        scheme.surface,
        Icon(Icons.school, size: 18, color: scheme.surface),
      ),
      // 아직 가지 않은 정차 — 채운 원으로 눈에 띄게(§5.3 "다음 정차").
      MapMarkerKind.stop => (
        scheme.primary,
        scheme.onPrimary,
        Text(
          spec.label ?? '',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      MapMarkerKind.visitedStop => (
        scheme.surfaceContainerHigh,
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
        style: theme.textTheme.labelLarge?.copyWith(color: foreground),
        child: content,
      ),
    );

    if (spec.onTap == null) return pin;
    return GestureDetector(onTap: spec.onTap, child: pin);
  }
}
