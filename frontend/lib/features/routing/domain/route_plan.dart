import 'dart:convert';

import '../../../core/map/spec/map_view_adapter.dart';
import '../data/dto/route_plan_dto.dart';
import 'route_plan_status.dart';

/// 운행 방향. 같은 학생이라도 방향에 따라 장소·순서가 다르다.
enum RouteDirection {
  pickup('PICKUP', '등원'),
  dropoff('DROPOFF', '하원');

  const RouteDirection(this.wireName, this.label);

  final String wireName;
  final String label;

  static RouteDirection? fromWire(String? value) {
    for (final d in RouteDirection.values) {
      if (d.wireName == value) return d;
    }
    return null;
  }
}

/// 화면이 쓰는 노선 모델.
///
/// DTO 를 따로 두고 이 모델로 변환하는 이유(컨벤션 §4): 서버의 `polyline` 은
/// **JSON 문자열**인 데다 좌표 순서가 `[경도, 위도]` 라 화면이 그대로 쓸 수 없다.
/// 이 변환을 화면에서 하면 지도를 쓰는 모든 화면이 같은 파싱을 반복하게 된다.
class RoutePlan {
  const RoutePlan({
    required this.id,
    required this.busId,
    required this.direction,
    required this.serviceDate,
    required this.totalDistanceM,
    required this.totalDuration,
    required this.path,
    required this.stops,
    this.status = RoutePlanStatus.draft,
    this.version = 1,
  });

  final int id;
  final int busId;
  final RouteDirection direction;
  final DateTime serviceDate;
  final double totalDistanceM;
  final Duration totalDuration;

  /// 실도로 경로 좌표. 서버가 못 주면 빈 목록(지도에 선을 안 그린다).
  final List<GeoPoint> path;

  final List<RouteStop> stops;

  /// 승인 단계. 관리자 화면이 "제안"과 "배포됨"을 구분하는 데 쓴다.
  ///
  /// 기본값을 둔 건 이 필드를 나중에 덧붙였기 때문이고, 결손을 감추려는 게 아니다 —
  /// 서버 응답에는 `status` 가 항상 있고 [fromDto] 는 언제나 실제 값을 채운다.
  final RoutePlanStatus status;

  /// 재계산 회차. 같은 버스·방향으로 다시 배차하면 서버가 기존 행을 고치지 않고
  /// **version 을 올린 새 행**을 만든다 — 목록에 계획이 쌓이는 이유가 이것이다.
  final int version;

  /// 사람이 읽는 거리 — `1566.0` → `1.6km`, `860` → `860m`
  String get distanceLabel => totalDistanceM >= 1000
      ? '${(totalDistanceM / 1000).toStringAsFixed(1)}km'
      : '${totalDistanceM.round()}m';

  /// 사람이 읽는 소요 시간 — `397초` → `약 7분`
  String get durationLabel {
    final minutes = (totalDuration.inSeconds / 60).round();
    if (minutes < 1) return '1분 미만';
    if (minutes < 60) return '약 $minutes분';
    return '약 ${minutes ~/ 60}시간 ${minutes % 60}분';
  }

  /// 서버가 쓰는 `yyyy-MM-dd`.
  ///
  /// 요청 쿼리(`serviceDate=`)와 화면 표시가 같은 형식이라 한 곳에 둔다 —
  /// 두 군데서 각자 만들면 한쪽만 고쳐져 조회 결과가 어긋난다.
  static String formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String get serviceDateLabel => formatDate(serviceDate);

  static RoutePlan fromDto(RoutePlanDto dto) {
    return RoutePlan(
      id: dto.id,
      busId: dto.busId,
      direction:
          RouteDirection.fromWire(dto.direction) ?? RouteDirection.pickup,
      serviceDate: DateTime.parse(dto.serviceDate),
      totalDistanceM: dto.totalDistanceM,
      totalDuration: Duration(seconds: dto.totalDurationS.round()),
      path: parsePolyline(dto.polyline),
      stops: dto.stops.map(RouteStop.fromDto).toList(growable: false),
      status: RoutePlanStatus.fromWire(dto.status) ?? RoutePlanStatus.draft,
      version: dto.version,
    );
  }

  /// ⚠️ 서버 `polyline` 파싱 — 두 번 틀리기 쉬운 지점이다.
  ///
  /// 1. 값이 **JSON 배열이 아니라 JSON 문자열**이다 → `jsonDecode` 를 한 번 더 해야 한다
  /// 2. 각 원소가 **`[경도, 위도]`** 순서다 → `GeoPoint(lat, lng)` 와 **반대**라 뒤집어야 한다.
  ///    안 뒤집으면 노선이 서해 한가운데 그려진다
  ///
  /// 형식이 깨져 있으면 빈 목록을 돌려준다 — 경로선이 없다고 화면 전체가 죽을 이유는 없다.
  static List<GeoPoint> parsePolyline(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];

    final points = <GeoPoint>[];
    for (final entry in decoded) {
      if (entry is! List || entry.length < 2) continue;
      final lng = entry[0];
      final lat = entry[1];
      if (lng is! num || lat is! num) continue;
      points.add(GeoPoint(lat.toDouble(), lng.toDouble()));
    }
    return points;
  }
}

class RouteStop {
  const RouteStop({
    required this.seq,
    required this.studentId,
    required this.point,
    required this.eta,
  });

  final int seq;

  /// ⚠️ 이름이 아니라 id 다. 이름은 운행 세션 명단에서만 온다(C7).
  final int studentId;

  final GeoPoint point;

  /// 노선 시작 기준 누적 도착 예정 시간.
  final Duration eta;

  /// 사람이 읽는 도착 예정 — `0초` → `출발`, `397초` → `7분 후`
  String get etaLabel {
    if (eta.inSeconds <= 0) return '출발';
    final minutes = (eta.inSeconds / 60).round();
    return minutes < 1 ? '곧 도착' : '$minutes분 후';
  }

  static RouteStop fromDto(RoutePlanStopDto dto) => RouteStop(
    seq: dto.seq,
    studentId: dto.studentId,
    point: GeoPoint(dto.lat, dto.lng),
    eta: Duration(seconds: dto.etaSeconds),
  );
}
