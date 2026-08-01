import '../../core/map/spec/map_view_adapter.dart';

/// **같은 좌표를 하나의 정차로 묶는 키.**
///
/// 서버는 정차를 **학생 단위**로 준다 — `stops[]` 도, 운행 명단도 학생 한 명당 한
/// 줄이고, 같은 정류장에서 타는 학생 4명은 같은 좌표가 4번 온다(2026-07-29 실측:
/// `GET /api/route-plans/driver/1` 이 정차 2곳에 대해 6줄을 준다). 화면은 정차
/// 단위로 그려야 하므로 어딘가에서 묶어야 하는데, 서버가 정차 id 를 안 주니
/// **좌표가 유일한 그룹 키**다.
///
/// 등원·하원 모두 이 규칙 하나로 처리된다:
///  - 등원 → 같은 `boarding_stop` 을 쓰는 학생들이 자연히 한 그룹이 된다
///  - 하원 → 하차지는 학생별 주소라 대개 1명씩이지만, 형제처럼 주소가 같으면 묶인다
///
/// 이 클래스가 `shared/` 에 있는 이유: 노선(`routing`)과 명단(`rideevent`) 두
/// feature 가 **같은 키로 묶어야** 지도 마커 번호와 명단 그룹 번호가 어긋나지
/// 않는다. 한쪽에 두고 다른 쪽이 참조하면 feature 간 의존이 된다(컨벤션 C-1).
class StopKey {
  const StopKey._(this._value);

  /// ⚠️ `double` 을 그대로 비교하지 않는다.
  ///
  /// 노선의 `stops[].lat` 과 명단의 `roster[].lat` 은 백엔드에서 같은 컬럼을 읽어
  /// 오지만(`RoutingCommandService` 와 `DriveSessionQueryService` 가 둘 다
  /// `boardingStop`/`dropoffLat` 을 쓴다), JSON 을 오가며 마지막 자리가 흔들리면
  /// 그룹이 조용히 둘로 쪼개진다. 그러면 마커가 겹쳐 찍히고 명단 번호가 밀린다.
  ///
  /// 소수점 5자리는 약 1m 분해능이다 — 같은 정류장을 다른 정차로 볼 일도,
  /// 다른 정류장을 같은 정차로 볼 일도 없는 자리수다.
  factory StopKey.of(GeoPoint point) {
    final lat = point.lat.toStringAsFixed(_precision);
    final lng = point.lng.toStringAsFixed(_precision);
    return StopKey._('$lat,$lng');
  }

  static const int _precision = 5;

  final String _value;

  @override
  bool operator ==(Object other) => other is StopKey && other._value == _value;

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => 'StopKey($_value)';
}
