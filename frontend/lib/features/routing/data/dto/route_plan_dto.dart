/// `GET /api/route-plans/...` 응답 `data`. **서버 표현 그대로** 담는다.
///
/// 화면이 쓰기 좋은 형태로 바꾸는 건 `RoutePlan`(domain) 의 일이다(컨벤션 §4) —
/// 특히 [polyline] 은 이대로는 못 쓴다(§ `RoutePlan.parsePolyline` 주석 참조).
class RoutePlanDto {
  const RoutePlanDto({
    required this.id,
    required this.busId,
    required this.direction,
    required this.status,
    required this.serviceDate,
    required this.totalDistanceM,
    required this.totalDurationS,
    required this.polyline,
    required this.stops,
  });

  final int id;
  final int busId;

  /// `PICKUP`(등원) / `DROPOFF`(하원)
  final String direction;

  /// `DRAFT` → `RECOMMENDED` → `APPROVED` → `PUBLISHED`
  final String status;

  final String serviceDate;
  final double totalDistanceM;
  final double totalDurationS;

  /// ⚠️ **JSON 배열이 아니라 JSON 문자열**이다: `"[[127.0275,37.501], ...]"`
  final String? polyline;

  final List<RoutePlanStopDto> stops;

  static RoutePlanDto fromJson(Map<String, dynamic> json) => RoutePlanDto(
    id: json['id'] as int,
    busId: json['busId'] as int,
    direction: json['direction'] as String,
    status: json['status'] as String,
    serviceDate: json['serviceDate'] as String,
    totalDistanceM: (json['totalDistanceM'] as num?)?.toDouble() ?? 0,
    totalDurationS: (json['totalDurationS'] as num?)?.toDouble() ?? 0,
    polyline: json['polyline'] as String?,
    stops: ((json['stops'] as List?) ?? const [])
        .map((e) => RoutePlanStopDto.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );
}

/// ⚠️ **학생 이름이 없다.** `studentId` 뿐이다 —
/// 이름은 운행 세션 명단(`GET /api/drive-sessions/{id}/roster`)에서만 온다(계획서 §3.11).
class RoutePlanStopDto {
  const RoutePlanStopDto({
    required this.seq,
    required this.studentId,
    required this.lat,
    required this.lng,
    required this.etaSeconds,
  });

  final int seq;
  final int studentId;
  final double lat;
  final double lng;

  /// 노선 시작 기준 누적 도착 예정 시간(**초**).
  final int etaSeconds;

  static RoutePlanStopDto fromJson(Map<String, dynamic> json) =>
      RoutePlanStopDto(
        seq: json['seq'] as int,
        studentId: json['studentId'] as int,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        etaSeconds: (json['etaSeconds'] as num?)?.toInt() ?? 0,
      );
}
