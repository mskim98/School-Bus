/// `GET /api/locations/buses` 응답 `data` 의 원소. **서버 표현 그대로** 담는다.
///
/// ⚠️ **위치 보고가 한 번도 없는 버스는 이 배열에 아예 없다**(계획서 §3.6, Swagger 실측).
/// 그래서 이 목록만으로는 "버스가 없다"와 "위치를 모른다"를 구분할 수 없어,
/// `GET /api/buses` 목록과 합쳐야 관제 화면이 완성된다(→ `MonitoredBus`).
class BusLocationDto {
  const BusLocationDto({
    required this.busId,
    required this.busName,
    required this.lat,
    required this.lng,
    required this.recordedAt,
    required this.origin,
  });

  final int busId;
  final String busName;
  final double lat;
  final double lng;

  /// ⚠️ **타임존 정보가 없는 서버 로컬 시각**이다: `"2026-07-28T12:34:26.199274169"`.
  ///
  /// 백엔드가 `LocalDateTime` 을 그대로 직렬화하고 컨테이너는 UTC 로 도는 반면
  /// 브라우저는 KST 라, 이 값을 파싱해 "몇 시"로 보여주면 9시간 어긋난다.
  /// **절대 시각 표시에 쓰지 않는다** — 값이 바뀌었는지 판별하는 용도로만 쓰고,
  /// 신선도는 클라이언트가 응답을 받은 시각으로 잰다(`MonitoredBus.observedAt`).
  final String recordedAt;

  /// `GPS` / `MOCK`. 좌표를 만든 쪽이 보고에 실어 보낸 값을 서버가 그대로 기록한다
  /// — 기사 앱의 Mock/실GPS 토글, 백엔드 시뮬레이터가 각각 자기 출처를 붙인다.
  /// `origin` 없이 들어온 보고는 서버가 `GPS` 로 기록한다.
  final String origin;

  static BusLocationDto fromJson(Map<String, dynamic> json) => BusLocationDto(
    busId: json['busId'] as int,
    busName: json['busName'] as String? ?? '',
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    recordedAt: json['recordedAt'] as String? ?? '',
    origin: json['origin'] as String? ?? '',
  );
}
