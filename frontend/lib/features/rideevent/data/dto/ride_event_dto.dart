/// `POST /api/ride-events` · `GET /api/ride-events/bus/{busId}` 응답 `data`.
/// **서버 표현 그대로** 담는다.
///
/// enum·시각 변환은 `RideEvent`(domain) 가 한다(컨벤션 §4).
class RideEventDto {
  const RideEventDto({
    required this.id,
    required this.studentId,
    required this.busId,
    required this.type,
    required this.occurredAt,
    this.stopId,
    this.lat,
    this.lng,
    this.source,
  });

  final int id;
  final int studentId;
  final int busId;

  /// `BOARD` / `ALIGHT` / `HANDOVER`
  final String type;

  /// ⚠️ 오프셋 없는 로컬 시각: `2026-07-28T12:34:10.753933259`.
  final String occurredAt;

  /// 요청에서 생략하면 서버가 학생의 기본 정류장으로 채워 돌려준다.
  final int? stopId;

  final double? lat;
  final double? lng;

  /// `QR` / `NFC` / `MANUAL` / `CORRECTION`. 기사 수동 기록은 서버가 `MANUAL` 로 채운다.
  final String? source;

  static RideEventDto fromJson(Map<String, dynamic> json) => RideEventDto(
    id: json['id'] as int,
    studentId: json['studentId'] as int,
    busId: json['busId'] as int,
    type: json['type'] as String,
    occurredAt: json['occurredAt'] as String,
    stopId: json['stopId'] as int?,
    lat: (json['lat'] as num?)?.toDouble(),
    lng: (json['lng'] as num?)?.toDouble(),
    source: json['source'] as String?,
  );
}
