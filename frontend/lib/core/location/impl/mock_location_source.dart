import 'dart:math' as math;

import '../../map/spec/map_view_adapter.dart';
import '../spec/location_source.dart';

/// 주어진 경로를 따라 왕복하며 좌표를 만들어내는 [LocationSource].
///
/// 기사 화면이 이미 조회해 둔 노선 polyline 을 그대로 넘겨받는다 — `core` 는
/// `features` 를 몰라야 하므로(검사 C-1) 경로를 **인자로** 받는다.
///
/// 왕복(삼각파)으로 도는 이유: 한 방향으로만 가면 종점에서 멈춰버려 시연이 끊긴다.
/// 백엔드 `MockBusLocationSource` 도 같은 방식이라 화면·서버가 어색하게 어긋나지 않는다.
class MockLocationSource implements LocationSource {
  MockLocationSource(this.path, {this.metersPerRead = defaultMetersPerRead})
    : _cumulative = _cumulativeDistances(path);

  /// 따라갈 경로. 비어 있으면 [read] 가 [LocationUnavailableException] 을 던진다.
  final List<GeoPoint> path;

  /// [read] 한 번에 전진하는 거리(m).
  ///
  /// 5초 주기 기준 60m ≈ 시속 43km — 시내버스 체감 속도다. 시드 노선(약 1.2km)을
  /// 한 방향 도는 데 100초쯤 걸려 시연 중에 눈에 띄게 움직인다.
  final double metersPerRead;

  static const double defaultMetersPerRead = 60;

  /// `_cumulative[i]` = 경로 시작점부터 `path[i]` 까지의 누적 거리(m).
  final List<double> _cumulative;

  /// 시작점부터 현재까지 이동한 거리(m).
  double _traveled = 0;

  /// 진행 방향. 종점에 닿으면 -1 로 뒤집혀 되돌아온다.
  int _heading = 1;

  double get _totalMeters => _cumulative.isEmpty ? 0 : _cumulative.last;

  @override
  Future<GeoPoint> read() async {
    if (path.isEmpty) {
      throw const LocationUnavailableException(
        '따라갈 노선이 없어 가상 위치를 만들 수 없습니다. 노선이 배포된 뒤 다시 시도하거나 실 GPS 로 전환해 주세요',
      );
    }

    // 현재 위치를 먼저 돌려주고 다음 호출을 위해 전진시킨다 —
    // 첫 호출이 출발지를 주도록 해서 "켰더니 엉뚱한 곳에서 시작"하지 않게 한다.
    final point = _pointAt(_traveled);
    _advance();
    return point;
  }

  void _advance() {
    final total = _totalMeters;
    if (total <= 0) return; // 점이 하나뿐인 경로 — 움직일 곳이 없다

    _traveled += _heading * metersPerRead;
    if (_traveled >= total) {
      _traveled = total;
      _heading = -1;
    } else if (_traveled <= 0) {
      _traveled = 0;
      _heading = 1;
    }
  }

  /// 시작점에서 [meters] 만큼 떨어진 지점을 선형 보간으로 구한다.
  GeoPoint _pointAt(double meters) {
    if (path.length == 1) return path.first;
    if (meters <= 0) return path.first;
    if (meters >= _totalMeters) return path.last;

    // 누적 거리가 meters 를 넘어서는 첫 구간을 찾는다.
    var i = 1;
    while (i < _cumulative.length - 1 && _cumulative[i] < meters) {
      i++;
    }

    final segmentStart = _cumulative[i - 1];
    final segmentLength = _cumulative[i] - segmentStart;
    // 길이 0인 구간(같은 좌표가 연달아 있는 경우)에서 0으로 나누지 않는다.
    final t = segmentLength <= 0
        ? 0.0
        : (meters - segmentStart) / segmentLength;

    final from = path[i - 1];
    final to = path[i];
    return GeoPoint(
      from.lat + (to.lat - from.lat) * t,
      from.lng + (to.lng - from.lng) * t,
    );
  }

  static List<double> _cumulativeDistances(List<GeoPoint> path) {
    if (path.isEmpty) return const [];
    final result = <double>[0];
    for (var i = 1; i < path.length; i++) {
      result.add(result[i - 1] + distanceMeters(path[i - 1], path[i]));
    }
    return result;
  }

  /// 두 점 사이 거리(m) — 등장방형(equirectangular) 근사.
  ///
  /// 도시 규모(수 km)에서 오차가 1% 미만이라 Mock 속도 계산에는 충분하다.
  /// 삼각함수 호출이 적어 매 tick 돌려도 가볍다.
  static double distanceMeters(GeoPoint a, GeoPoint b) {
    const earthRadiusM = 6371000.0;
    final latRad = (a.lat + b.lat) / 2 * math.pi / 180;
    final dLat = (b.lat - a.lat) * math.pi / 180;
    final dLng = (b.lng - a.lng) * math.pi / 180 * math.cos(latRad);
    return earthRadiusM * math.sqrt(dLat * dLat + dLng * dLng);
  }
}
