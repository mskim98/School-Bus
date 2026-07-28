/// `GET /api/buses` 응답 `data` 의 원소 중 **관제 화면이 쓰는 필드만** 담는다.
///
/// 서버 `BusResponse` 에는 정원·보험만료일 등 13개 필드가 있지만 관제 지도에서는
/// 쓰지 않는다. 안 쓰는 필드를 다 옮겨 적으면 서버가 바뀔 때마다 무의미하게 깨진다.
///
/// 📌 원래 자리는 `features/bus/` 다. 버스 관리 화면이 생기면 그쪽으로 옮기고
/// 관제 화면은 그 DTO 를 재사용한다 — 지금은 이 화면 하나만 쓰므로 여기 둔다.
class BusSummaryDto {
  const BusSummaryDto({
    required this.id,
    required this.name,
    this.plateNumber,
    this.driverName,
  });

  final int id;
  final String name;
  final String? plateNumber;

  /// 배차되지 않은 버스는 null 이다(시드의 1호차가 그렇다).
  final String? driverName;

  static BusSummaryDto fromJson(Map<String, dynamic> json) => BusSummaryDto(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    plateNumber: json['plateNumber'] as String?,
    driverName: json['driverName'] as String?,
  );
}
