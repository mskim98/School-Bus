/// `GET /api/buses` 응답의 한 줄(권한 `ACADEMY_ADMIN`·`PLATFORM_ADMIN`).
///
/// 기사용 [MyBusDto](my_bus_dto.dart) 와 **일부러 나눠 둔다.** 같은 서버 레코드지만
/// 관리자 화면은 기사가 안 쓰는 값(기사 이름·배정 정원·초과 경고)을 쓰고, 기사 화면은
/// 관리자가 안 쓰는 값을 뺀다. 하나로 합치면 어느 화면도 안 보는 필드가 생기고
/// 서버가 바뀔 때 아무도 모르는 자리에서 파싱이 깨진다(컨벤션 §4).
class BusDto {
  const BusDto({
    required this.id,
    required this.seatCapacity,
    required this.assignedCount,
    this.name,
    this.plateNumber,
    this.driverName,
    this.routeName,
    this.assignCapacity,
    this.overCapacity = false,
  });

  final int id;
  final String? name;
  final String? plateNumber;

  /// 물리 좌석 수. **배차 알고리즘이 상한으로 쓰는 값이다**
  /// (`SweepAssigner` 가 이 수만큼 채우고 넘기면 다음 버스로 넘어간다).
  final int seatCapacity;

  /// 이 버스에 배정된 학생 수.
  ///
  /// ⚠️ 서버 필드명은 `onboard` 지만 **지금 타고 있는 인원이 아니다** — 배정 명부의
  /// 크기다(`findByAssignedBusId(busId).size()`). 이름을 물려받으면 관제 화면이
  /// 현재 탑승 인원으로 착각해 그린다.
  final int assignedCount;

  /// 노선이 정한 배정 정원. 좌석 수와 **다른 개념**이고 노선이 없으면 null.
  final int? assignCapacity;

  /// 서버가 판정한 초과 배정 경고(`assignedCount > assignCapacity`).
  final bool overCapacity;

  final String? driverName;
  final String? routeName;

  static BusDto fromJson(Map<String, dynamic> json) => BusDto(
    id: json['id'] as int,
    seatCapacity: json['seatCapacity'] as int,
    assignedCount: json['onboard'] as int,
    name: json['name'] as String?,
    plateNumber: json['plateNumber'] as String?,
    driverName: json['driverName'] as String?,
    routeName: json['routeName'] as String?,
    assignCapacity: json['assignCapacity'] as int?,
    overCapacity: json['overCapacity'] as bool? ?? false,
  );
}
