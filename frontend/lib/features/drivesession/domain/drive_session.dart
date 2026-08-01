import '../../../core/map/spec/map_view_adapter.dart';
import '../data/dto/drive_session_dto.dart';

/// 운행 방향.
///
/// `routing` feature 의 `RouteDirection` 과 값이 같지만 **일부러 따로 둔다** —
/// feature 끼리 서로의 코드를 참조하면 안 되고(컨벤션 C-1), 진짜로 공유하려면
/// `shared/domain/` 으로 올려야 하는데 그건 별도 작업 범위다.
enum DriveDirection {
  pickup('PICKUP', '등원'),
  dropoff('DROPOFF', '하원');

  const DriveDirection(this.wireName, this.label);

  /// 서버가 쓰는 값.
  final String wireName;

  /// 화면에 그대로 쓰는 한글 이름.
  final String label;

  /// 모르는 값이면 null. 서버에 방향이 추가돼도 앱이 죽지 않게 한다.
  static DriveDirection? fromWire(String? value) {
    for (final direction in DriveDirection.values) {
      if (direction.wireName == value) return direction;
    }
    return null;
  }
}

/// 기사의 한 번 운행. 화면이 쓰는 모델.
///
/// DTO 를 그대로 안 쓰는 이유(컨벤션 §4): `status`·`direction` 이 문자열이고
/// `startedAt`·`serviceDate` 가 파싱 안 된 문자열이라, 화면이 쓰려면 매번 같은
/// 변환을 반복해야 한다. 변환은 경계(repository)에서 한 번만 한다.
class DriveSession {
  const DriveSession({
    required this.id,
    required this.busId,
    required this.direction,
    required this.serviceDate,
    required this.isInProgress,
    required this.startedAt,
    this.endedAt,
  });

  final int id;
  final int busId;
  final DriveDirection direction;

  /// 운행 대상 날짜. `GET /api/ride-events/bus/{busId}?date=` 에 그대로 쓴다.
  final DateTime serviceDate;

  /// `status == IN_PROGRESS`. 이 값이 true 인 세션이 "지금 운행 중"이다.
  final bool isInProgress;

  final DateTime startedAt;
  final DateTime? endedAt;

  /// 운행 소요 시간. 아직 안 끝났으면 null.
  Duration? get elapsed => endedAt?.difference(startedAt);

  static DriveSession fromDto(DriveSessionDto dto) => DriveSession(
    id: dto.id,
    busId: dto.busId,
    // 모르는 방향 값이 와도 화면을 못 그리는 것보다는 등원으로 보여주는 편이 낫다.
    direction: DriveDirection.fromWire(dto.direction) ?? DriveDirection.pickup,
    serviceDate: DateTime.parse(dto.serviceDate),
    isInProgress: dto.status == 'IN_PROGRESS',
    startedAt: DateTime.parse(dto.startedAt),
    endedAt: dto.endedAt == null ? null : DateTime.parse(dto.endedAt!),
  );
}

/// 운행 명단의 한 명. **이 이름은 운행 세션에서만 온다.**
class RosterEntry {
  const RosterEntry({
    required this.studentId,
    required this.name,
    this.location,
    this.point,
  });

  final int studentId;
  final String name;

  /// 등원이면 승차 정류장, 하원이면 하차지.
  final String? location;

  /// 승차 정류장 또는 하차지의 좌표.
  ///
  /// 표시용이 아니라 **묶음용**이다 — 서버가 명단을 학생 단위로 주기 때문에,
  /// 화면이 "이 정류장에서 2명"처럼 정차 단위로 그리려면 좌표로 묶는 수밖에 없다
  /// (`shared/domain/stop_key.dart`). 서버가 정차 id 를 안 준다.
  ///
  /// 좌표가 없는 학생(정류장 미지정 등)은 null 이고, 그런 학생은 묶이지 않고
  /// 각자 한 그룹이 된다.
  final GeoPoint? point;

  static RosterEntry fromDto(DriveSessionRosterEntryDto dto) => RosterEntry(
    studentId: dto.studentId,
    name: dto.name,
    location: dto.location,
    point: dto.lat == null || dto.lng == null
        ? null
        : GeoPoint(dto.lat!, dto.lng!),
  );
}
