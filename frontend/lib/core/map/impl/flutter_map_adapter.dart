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
    void Function(MapCameraController)? onReady,
    EdgeInsets obscured = EdgeInsets.zero,
  }) {
    return _FlutterMapView(
      markers: markers,
      routes: routes,
      onReady: onReady,
      obscured: obscured,
    );
  }

  static LatLng _toLatLng(GeoPoint p) => LatLng(p.lat, p.lng);
}

/// [MapCameraController] 를 `flutter_map` 의 [MapController] 로 옮기는 얇은 껍데기.
///
/// 화면에 [MapController] 를 그대로 넘기지 않는 이유: 그러면 지도 라이브러리
/// 타입이 이 파일 밖으로 새어 나가 포트가 무의미해진다(컨벤션 §5).
class _FlutterMapCamera implements MapCameraController {
  _FlutterMapCamera(this._controller, this._fit);

  final MapController _controller;

  /// 현재 마커·경로 기준 bounds 를 다시 계산해 주는 함수.
  /// 값이 아니라 함수로 받는 이유는 마커가 갱신돼도 최신 좌표로 맞추기 위해서다.
  final CameraFit? Function() _fit;

  @override
  void moveTo(GeoPoint point, {double? zoom}) {
    _controller.move(
      FlutterMapAdapter._toLatLng(point),
      zoom ?? _controller.camera.zoom,
    );
  }

  @override
  void fitAll() {
    final fit = _fit();
    // 그려진 좌표가 없으면 맞출 대상도 없다 — 임의로 움직이지 않는다.
    if (fit == null) return;
    _controller.fitCamera(fit);
  }

  @override
  void zoomBy(double delta) {
    final camera = _controller.camera;
    // 타일이 없는 배율로 넘어가면 지도가 통째로 회색이 된다. OSM 타일 범위 안에 가둔다.
    final zoom = (camera.zoom + delta).clamp(3.0, 18.0);
    _controller.move(camera.center, zoom);
  }
}

/// [MapController] 수명을 들고 있어야 해서 Stateful 이다.
/// (컨트롤러를 build 마다 새로 만들면 카메라 명령이 이전 지도로 날아간다.)
class _FlutterMapView extends StatefulWidget {
  const _FlutterMapView({
    required this.markers,
    required this.routes,
    this.onReady,
    this.obscured = EdgeInsets.zero,
  });

  final List<MapMarkerSpec> markers;
  final List<MapRouteSpec> routes;
  final void Function(MapCameraController)? onReady;

  /// 다른 위젯이 지도를 덮고 있는 넓이. 이만큼 피해서 좌표를 맞춘다.
  final EdgeInsets obscured;

  @override
  State<_FlutterMapView> createState() => _FlutterMapViewState();
}

class _FlutterMapViewState extends State<_FlutterMapView> {
  final _controller = MapController();

  /// 여백 없이 맞추면 마커가 화면 가장자리에 붙어 잘린 것처럼 보인다.
  static const double _fitMargin = 48;

  /// 지도가 실제로 붙은 뒤에만 카메라를 움직일 수 있다.
  bool _ready = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// ⚠️ **그려진 좌표가 바뀌면 카메라를 다시 맞춘다.**
  ///
  /// `MapOptions.initialCameraFit` 은 이름 그대로 **최초 1회**만 적용된다. 그래서
  /// 등원↔하원을 전환하면 경로선과 마커는 새로 그려지는데 카메라는 이전 노선에
  /// 머문다 — 등원(1.6km)을 보다가 하원(4.6km)으로 바꾸면 하원 경로 대부분이
  /// 화면 밖으로 나가, 보이는 부분만으로는 **두 노선이 같아 보인다.**
  /// (2026-07-29 실측: 등원 1566m/453s, 하원 4618m/1534s 로 실제로는 전혀 다르다.)
  @override
  void didUpdateWidget(_FlutterMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (_geometryOf(oldWidget) == _geometryOf(widget)) return;

    final fit = _fit();
    if (fit == null) return;
    // 빌드 중에 카메라를 움직이면 flutter_map 이 같은 프레임에서 다시 그린다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.fitCamera(fit);
    });
  }

  /// 카메라를 다시 맞출지 판단하는 기준. 좌표 목록이 같으면 그릴 그림도 같다.
  ///
  /// **버스 마커는 세지 않는다** — 몇 초마다 움직이므로 포함하면 카메라가 계속
  /// 리셋돼 기사가 확대해 둔 화면이 사라진다. `_fit()` 과 같은 이유다.
  static String _geometryOf(_FlutterMapView view) => [
    for (final m in view.markers)
      if (m.kind != MapMarkerKind.bus) '${m.point.lat},${m.point.lng}',
    for (final r in view.routes)
      for (final p in r.points) '${p.lat},${p.lng}',
  ].join('|');

  /// 마커·경로가 모두 화면에 들어오도록 맞춘다.
  ///
  /// 시드 데이터 기준 경로가 대각선 1.2km 정도로 좁아, 여백 없이 맞추면 마커가
  /// 가장자리에 붙는다. 그래서 패딩을 넉넉히 준다.
  ///
  /// 첫 진입 시의 `initialCameraFit` 과 `전체 경로` 버튼이 **같은 계산**을 쓴다 —
  /// 둘이 갈라지면 버튼을 눌렀을 때 처음과 다른 화면이 나온다.
  CameraFit? _fit() {
    final points = <LatLng>[
      // ⚠️ 버스 마커는 뺀다. 버스는 몇 초마다 움직이는 값이라, 이걸 넣으면
      // ① `전체 경로` 가 기사 위치까지 담느라 정작 경로를 잘게 만들고
      // ② 아래 [didUpdateWidget] 의 재조정이 매 좌표 갱신마다 발동해
      //    기사가 손으로 확대해 둔 화면을 계속 되돌린다.
      for (final m in widget.markers)
        if (m.kind != MapMarkerKind.bus) FlutterMapAdapter._toLatLng(m.point),
      for (final r in widget.routes)
        for (final p in r.points) FlutterMapAdapter._toLatLng(p),
    ];
    if (points.isEmpty) return null;

    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      // 가려진 넓이를 여백에 더한다. 이게 없으면 경로가 지도 한가운데 놓이는데,
      // 그 한가운데는 정차 시트에 덮여 있어 **기사 눈에는 화면 아래로 치우쳐
      // 보인다.** 더해 주면 실제로 보이는 영역의 한가운데에 경로가 온다.
      padding: const EdgeInsets.all(_fitMargin) + widget.obscured,
      // 점이 하나뿐이면 bounds 가 한 점이라 무한대로 확대된다.
      maxZoom: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fit = _fit();
    final markers = widget.markers;
    final routes = widget.routes;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        // 지도가 실제로 준비된 뒤에 손잡이를 넘긴다 — 그 전에 넘기면 화면이
        // 즉시 카메라를 움직였을 때 컨트롤러가 아직 지도에 붙어 있지 않다.
        onMapReady: () {
          _ready = true;
          widget.onReady?.call(_FlutterMapCamera(_controller, _fit));
        },
        initialCenter: FlutterMapAdapter._fallbackCenter,
        initialZoom: 14,
        initialCameraFit: fit,
        interactionOptions: const InteractionOptions(
          // 회전은 운전 중 오조작으로 지도가 돌아가는 사고만 만든다. 나머지 확대
          // 수단은 전부 연다 — `pinchZoom` 만 두면 **마우스로는 확대가 아예 안 된다**
          // (관리자가 데스크톱에서 열 때, 기사 화면을 브라우저로 검수할 때).
          flags:
              InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.scrollWheelZoom |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.doubleTapDragZoom,
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
                    //
                    // 9 → 6 (2026-07-29): 케이싱을 두르고 나니 9 는 지도를 덮어
                    // 정차 마커와 도로 이름을 가렸다. 굵기로 벌던 대비를 테두리가
                    // 대신하므로 본선을 줄여도 식별성은 유지된다.
                    strokeWidth: 6,
                    color: Theme.of(context).colorScheme.primary,
                    // 케이싱(어두운 테두리). 굵기·본선 색은 §5.3 그대로 두고
                    // 테두리만 덧댄다 — OSM 타일의 회색 도로선과 경로선이
                    // 겹치면 경계가 뭉개져 "선이 어디까지인지"가 안 읽혔다.
                    // 새 색을 만들지 않고 §1 의 `onPrimaryContainer`(#001945)를
                    // 쓴다. primary 계열 중 가장 어두워 대비가 제일 크다.
                    borderStrokeWidth: 2,
                    borderColor: Theme.of(
                      context,
                    ).colorScheme.onPrimaryContainer,
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

    // 마커를 지도 타일에서 떼어내는 기본 테두리. 밝은 테두리라 도로·건물 위
    // 어디에 놓여도 마커 윤곽이 살아난다.
    final detach = Border.all(color: scheme.surface, width: 2);

    // 색만으로 구분하지 않는다 — 직사광선 아래서도 읽히도록 아이콘·숫자를 함께 쓴다.
    final (
      Color background,
      Color foreground,
      Border border,
      Widget content,
    ) = switch (spec.kind) {
      // §5.3 이 정한 역할색만 쓴다. `secondary`·`tertiary` 는 시드에서 자동
      // 파생될 뿐 디자인 시스템 §1 이 정의한 역할이 아니라, 그 색이 무슨 뜻인지
      // 아무도 모른다 — 지도는 화면에서 가장 오래 보는 곳이라 특히 그렇다.
      MapMarkerKind.bus => (
        scheme.onSurface,
        scheme.surface,
        detach,
        Icon(Icons.directions_bus, size: 20, color: scheme.surface),
      ),
      MapMarkerKind.depot => (
        scheme.onSurface,
        scheme.surface,
        detach,
        Icon(Icons.school, size: 18, color: scheme.surface),
      ),
      // 다음 정차 — 채운 원으로 눈에 띄게(§5.3).
      MapMarkerKind.stop => (
        scheme.primary,
        scheme.onPrimary,
        detach,
        Text(
          spec.label ?? '',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      // 그 뒤에 남은 정차 — §5.3 이 정한 **테두리형**. 채움을 뺀 이유는
      // 정차가 5개일 때 채운 원 5개가 나란히 있으면 어디로 먼저 가는지가
      // 지도만 봐서는 안 보이기 때문이다. 다음 정차 하나만 채워 둔다.
      MapMarkerKind.upcomingStop => (
        scheme.surface,
        scheme.onSurface,
        Border.all(color: scheme.primary, width: 3),
        Text(
          spec.label ?? '',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      // 지나온 정차 — **순번을 지우지 않는다.** 체크 아이콘만 남기면 명단에는
      // 완료 그룹이 배지 ②로 남는데 지도에서는 번호가 사라져, 기사가 나중에
      // "②를 처리했나"를 되짚을 때 두 화면을 맞춰 볼 수 없다(§5.4-4).
      // 완료라는 사실은 톤(가라앉은 배경 + outline 글자)이 이미 말한다.
      MapMarkerKind.visitedStop => (
        scheme.surfaceContainerHigh,
        scheme.outline,
        detach,
        Text(
          spec.label ?? '',
          style: theme.textTheme.labelLarge?.copyWith(
            color: scheme.outline,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    };

    final pin = Container(
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: border,
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
