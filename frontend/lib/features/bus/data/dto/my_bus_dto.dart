/// `GET /api/buses/me` 응답 `data` 중 **기사 화면이 쓰는 필드만** 담는다.
///
/// 서버 `BusResponse` 에는 13개 필드가 있지만 기사 앱은 `tenantId`·`driverId`·
/// `driverName`(어차피 본인이다)·`insuranceExpiry`·`overCapacity`(관리자용 경고)를
/// 쓰지 않는다. 안 쓰는 필드까지 옮겨 적으면 서버가 바뀔 때마다 아무도 안 보는
/// 자리에서 파싱이 깨진다(컨벤션 §4).
class MyBusDto {
  const MyBusDto({
    required this.id,
    required this.seatCapacity,
    required this.onboard,
    this.name,
    this.plateNumber,
    this.routeName,
  });

  final int id;

  /// 호차명. 비어 왔을 때 뭐라고 표시할지는 DTO 가 정하지 않는다 —
  /// 여기서 `?? ''` 로 덮으면 "이름이 없다"와 "이름이 빈 문자열이다"가 같아진다.
  final String? name;

  final String? plateNumber;

  /// 물리 좌석 수. 서버가 `assignCapacity`(노선 배정 정원)와 **다른 개념으로**
  /// 따로 들고 있는 값이라 섞지 않는다.
  final int seatCapacity;

  /// 이 버스에 배정된 학생 수.
  ///
  /// ⚠️ 이름이 `onboard` 지만 **지금 타고 있는 인원이 아니다.** 서버는
  /// `findByAssignedBusId(busId).size()` 로 계산한다 — 배정 명부의 크기다.
  final int onboard;

  /// 배정된 노선이 없으면 null 이다.
  final String? routeName;

  static MyBusDto fromJson(Map<String, dynamic> json) => MyBusDto(
    id: json['id'] as int,
    seatCapacity: json['seatCapacity'] as int,
    onboard: json['onboard'] as int,
    name: json['name'] as String?,
    plateNumber: json['plateNumber'] as String?,
    routeName: json['routeName'] as String?,
  );
}
