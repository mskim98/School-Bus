/// `POST /api/drive-sessions/start` · `PATCH /api/drive-sessions/{id}/end` 응답 `data`.
/// **서버 표현 그대로** 담는다.
///
/// 날짜·시각·enum 으로 바꾸는 건 `DriveSession`(domain) 의 일이다(컨벤션 §4).
class DriveSessionDto {
  const DriveSessionDto({
    required this.id,
    required this.busId,
    required this.direction,
    required this.serviceDate,
    required this.status,
    required this.startedAt,
    this.routePlanId,
    this.endedAt,
  });

  final int id;
  final int busId;

  /// `PICKUP`(등원) / `DROPOFF`(하원)
  final String direction;

  /// `yyyy-MM-dd`
  final String serviceDate;

  /// `IN_PROGRESS` / `COMPLETED`
  final String status;

  /// ⚠️ **오프셋이 없는 로컬 시각**이다: `2026-07-28T12:33:35.616584007`.
  /// 소수점 이하 9자리가 오지만 `DateTime.parse` 가 마이크로초까지만 받고 나머지는 버린다.
  final String startedAt;

  final String? endedAt;

  /// 이 운행이 따르는 노선. 배차 전이면 null 이다.
  final int? routePlanId;

  static DriveSessionDto fromJson(Map<String, dynamic> json) => DriveSessionDto(
    id: json['id'] as int,
    busId: json['busId'] as int,
    direction: json['direction'] as String,
    serviceDate: json['serviceDate'] as String,
    status: json['status'] as String,
    startedAt: json['startedAt'] as String,
    endedAt: json['endedAt'] as String?,
    routePlanId: json['routePlanId'] as int?,
  );
}

/// `GET /api/drive-sessions/{id}/roster` 응답의 한 줄.
///
/// **학생 이름을 얻는 유일한 경로다.** 노선 API(`stops[]`)는 `studentId` 만 준다.
/// 결석 신고된 학생은 서버가 이미 빼고 내려준다.
class DriveSessionRosterEntryDto {
  const DriveSessionRosterEntryDto({
    required this.studentId,
    required this.name,
    this.location,
    this.lat,
    this.lng,
  });

  final int studentId;
  final String name;

  /// 등원이면 승차 정류장, 하원이면 하차지. 서버가 방향에 맞춰 골라 준다.
  final String? location;

  final double? lat;
  final double? lng;

  static DriveSessionRosterEntryDto fromJson(Map<String, dynamic> json) =>
      DriveSessionRosterEntryDto(
        studentId: json['studentId'] as int,
        name: json['name'] as String,
        location: json['location'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
      );
}
