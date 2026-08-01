import '../../../core/map/spec/map_view_adapter.dart';
import '../../../shared/domain/stop_key.dart';
import 'route_plan.dart';

/// 좌표가 같은 [RouteStop] 들을 묶은 **한 곳의 정차**.
///
/// 시안(`기사앱 MVP.dc.html` 279~287·349~364줄)은 지도 마커도 정차 카드도 정차
/// 단위로 그린다. 그런데 서버 `stops[]` 는 학생 단위라 그대로 그리면 같은 좌표에
/// 마커가 겹쳐 찍히고 카드가 학생 수만큼 나온다. 그 간극을 여기서 메운다.
///
/// **이름(`label`)은 운행을 시작해야 온다.** 노선 응답에는 정류장명이 없고
/// (`seq`·`studentId`·좌표·`etaSeconds` 뿐), 이름이 있는 곳은 운행 세션 명단
/// (`GET /api/drive-sessions/{id}/roster` 의 `location`)뿐인데 그건 시작 후에만
/// 조회된다. 그래서 시작 전에는 `1번 정차`, 시작 후에는 `정류장 A` 로 보인다.
class RouteStopGroup {
  const RouteStopGroup({
    required this.seq,
    required this.point,
    required this.eta,
    required this.studentIds,
    this.label,
    this.studentNames = const [],
  });

  /// 정차 순번. **1부터 이어지는 정차 번호**이지 서버 `seq` 가 아니다.
  ///
  /// 서버 `stops[].seq` 는 학생 번호라 정차로 묶으면 번호가 건너뛴다(실측: 정차
  /// 2곳에 `seq` 1·3). 방문 순서만 서버에서 가져오고 번호는 여기서 다시 매긴다.
  ///
  /// 지도 마커에 찍히는 숫자이자 명단 그룹 헤더의 배지 숫자이기도 하다 —
  /// 두 화면이 같은 값을 써야 기사가 지도와 목록을 대응시켜 볼 수 있다.
  final int seq;

  final GeoPoint point;

  /// 노선 시작 기준 도착 예정. 같은 좌표는 서버가 같은 값을 주므로 그룹 최솟값을 쓴다.
  final Duration eta;

  /// 이 정차에서 타거나 내리는 학생. **명단 조회 전에도 인원수는 알 수 있다.**
  final List<int> studentIds;

  /// 정류장명(등원) 또는 하차 주소(하원). 운행 시작 전에는 null.
  final String? label;

  /// 이 정차의 학생 이름. 운행 시작 전에는 빈 목록.
  final List<String> studentNames;

  int get studentCount => studentIds.length;

  /// 카드·마커에 쓰는 제목. 이름을 모르면 순번으로 부른다 —
  /// `정류장 A` 를 지어내면 다른 학원에서 틀린 이름이 뜬다.
  String get title => label ?? '$seq번 정차';

  /// 제목 아래 보조 줄. 이름을 알면 이름을, 모르면 인원수를 낸다.
  String get subtitle {
    if (studentNames.isEmpty) return '$studentCount명';
    if (studentNames.length == 1) return studentNames.first;
    return '${studentNames.first} 외 ${studentNames.length - 1}명';
  }

  /// 사람이 읽는 도착 예정 — [RouteStop.etaLabel] 규칙을 그대로 쓴다(§7-8).
  String get etaLabel {
    if (eta.inSeconds <= 0) return '출발';
    final minutes = (eta.inSeconds / 60).round();
    return minutes < 1 ? '곧 도착' : '$minutes분 후';
  }

  RouteStopGroup withRoster({String? label, List<String>? studentNames}) =>
      RouteStopGroup(
        seq: seq,
        point: point,
        eta: eta,
        studentIds: studentIds,
        label: label ?? this.label,
        studentNames: studentNames ?? this.studentNames,
      );

  /// 좌표가 같은 정차들을 묶는다. 결과는 [seq] 오름차순이다.
  ///
  /// 입력 순서를 믿지 않고 직접 정렬하는 이유: 그룹 순서가 곧 운행 순서라
  /// 여기가 어긋나면 기사가 잘못된 곳으로 간다.
  static List<RouteStopGroup> group(List<RouteStop> stops) {
    final buckets = <StopKey, List<RouteStop>>{};
    for (final stop in stops) {
      buckets.putIfAbsent(StopKey.of(stop.point), () => []).add(stop);
    }

    // 정렬 기준은 그룹 안의 **최소 seq** 다. 서버가 매긴 방문 순서를 그대로 따른다.
    final ordered = buckets.values.toList()
      ..sort((a, b) => _minSeq(a) - _minSeq(b));

    // ⚠️ 번호는 **1부터 다시 매긴다.** 서버 `seq` 는 정차 번호가 아니라 **학생
    // 번호**라, 최소 seq 를 그대로 배지에 쓰면 번호가 건너뛴다 — 실측(2026-07-29
    // 등원)에서 정차 2곳에 `seq` 1·3 이 나왔다. 기사는 ①③ 을 보고 "②는 어디
    // 갔나"를 찾는다. 학생 단위 번호를 화면에 흘리지 않는다.
    return [
      for (final (index, bucket) in ordered.indexed)
        RouteStopGroup(
          seq: index + 1,
          point: bucket.first.point,
          eta: bucket.map((s) => s.eta).reduce((a, b) => a < b ? a : b),
          studentIds: [
            for (final s in (bucket.toList()..sort((a, b) => a.seq - b.seq)))
              s.studentId,
          ],
        ),
    ];
  }

  static int _minSeq(List<RouteStop> bucket) =>
      bucket.map((s) => s.seq).reduce((a, b) => a < b ? a : b);
}
