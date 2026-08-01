/// `GET /api/tenants` 응답의 한 줄(권한 `PLATFORM_ADMIN`).
///
/// `lat`/`lng` 는 학원 위치(depot)다 — 배차 계산의 출발·도착점이라 서버가 이걸
/// 안 갖고 있으면 배차가 통째로 실패한다. 화면이 "위치 미설정" 학원을 구분할 수
/// 있어야 해서 null 을 그대로 남긴다.
class TenantDto {
  const TenantDto({required this.id, required this.name, this.lat, this.lng});

  final int id;
  final String name;
  final double? lat;
  final double? lng;

  static TenantDto fromJson(Map<String, dynamic> json) => TenantDto(
    id: json['id'] as int,
    name: json['name'] as String,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
  );
}
