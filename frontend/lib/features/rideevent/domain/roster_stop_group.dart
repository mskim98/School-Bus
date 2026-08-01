import '../../../core/map/spec/map_view_adapter.dart';
import '../../../shared/domain/stop_key.dart';
import '../../drivesession/domain/drive_session.dart';
import 'roster_student.dart';

/// 승하차 명단을 **정차 단위로 묶은 한 덩어리**(시안 406~469줄).
///
/// 지금까지 명단은 학생 행을 평평하게 나열했다. 3명이면 그래도 읽히지만 정원
/// 25명이면 "이 정류장에서 누구를 태워야 하는가"가 목록 어디에도 안 나온다.
/// 시안이 정차별로 접었다 펴는 카드를 둔 이유가 이것이다.
///
/// ⚠️ **하원을 `정류장 A/B` 로 묶지 않는다.** 시안 스크립트(744~749줄)는 하차
/// 그룹에 승차 정류장 이름을 재사용하고 `서초구 방면` 같은 상위 분류를 지어냈는데,
/// 실제로는 학생마다 자기 하차지에서 내린다(백엔드가 하원이면 `dropoffAddress` 를
/// 준다). 그래서 여기서는 **좌표가 같을 때만** 묶고 제목은 서버가 준 주소를 쓴다.
/// 주소가 다르면 1명짜리 그룹이 되는 게 맞다.
class RosterStopGroup {
  const RosterStopGroup({
    required this.seq,
    required this.students,
    required this.direction,
    this.label,
  });

  /// 헤더 배지에 찍히는 순번.
  ///
  /// 가능하면 **노선의 정차 순번을 그대로 쓴다**(화면이 `seqByStop` 으로 넘겨준다).
  /// 지도 마커의 숫자와 같아야 기사가 "지도의 ②가 명단의 ②"라고 읽을 수 있다.
  /// 노선이 아직 배포되지 않았으면 명단 등장 순서로 1부터 매긴다.
  final int seq;

  final List<RosterStudent> students;

  /// 등원/하원. 그룹이 승차 그룹인지 하차 그룹인지를 정한다.
  final DriveDirection direction;

  /// 정류장명(등원) 또는 하차 주소(하원). 서버가 안 주면 null.
  final String? label;

  /// 카드 제목. 이름을 모르면 순번으로 부른다 — 없는 정류장 이름을 지어내지 않는다.
  String get title => label ?? '$seq번 정차';

  /// 제목 옆 태그. 등원은 이 정차에서 **타고**, 하원은 **내린다**.
  String get kindLabel => direction == DriveDirection.pickup ? '승차' : '하차';

  /// 헤더 보조 줄 — `승차 2명` / `하차 1명`.
  String get countLabel => '$kindLabel ${students.length}명';

  /// 이 정차에서 처리가 끝난 인원.
  ///
  /// "끝났다"의 기준은 [RosterStudent.nextActionFor] 하나뿐이다 — 여기서 다시
  /// 정의하면 학생 행의 `✓ 완료` 표시와 그룹 진행률이 어긋난다.
  int get doneCount =>
      students.where((s) => s.nextActionFor(direction) == null).length;

  bool get isDone => students.isNotEmpty && doneCount == students.length;

  /// 헤더 우측 — `1/2명`.
  String get progressLabel => '$doneCount/${students.length}명';

  /// 접었을 때 대신 보여주는 한 줄.
  ///
  /// ⚠️ **§4 의 상태 라벨을 재사용하지 않는다.** 예전에는 `'$kindLabel 완료'` 로
  /// 조립해서 하원 그룹이 `하차 완료 · 1명` 으로 나왔는데, §4 에서 `하차 완료` 는
  /// **인계가 아직 남은 중간 상태**의 이름이다. 그래서
  ///  - 인계까지 끝난 정차가 "아직 인계 안 됨"으로 읽히고
  ///  - 반대로 `하차 대기 1명` 은 **이미 내린** 학생(인계만 남은)을 못 내린 것처럼
  ///    보여 하단의 잔류 인원 경고(`N명이 아직 차에 있습니다`)와 뜻이 겹친다
  ///
  /// 그룹은 학생 한 명의 단계가 아니라 **정차의 진행도**를 말하므로 자기 어휘를 쓴다.
  String get collapsedSummary => isDone
      ? '처리 완료 · ${students.length}명'
      : '남은 처리 ${students.length - doneCount}명 · 눌러서 펼치기';

  /// 이 정차의 좌표. 좌표가 없어 묶이지 못한 그룹이면 null.
  ///
  /// 노선(`RouteStopGroup`)과 이 그룹을 맞춰 볼 때 쓴다 — 화면이 `students.first`
  /// 를 다시 헤집지 않게 여기서 낸다. 같은 그룹의 학생은 정의상 좌표가 같으므로
  /// 어느 학생을 보든 결과가 같다.
  GeoPoint? get point => students.isEmpty ? null : students.first.point;

  /// [point] 를 그룹 키로 바꾼 값. 노선의 `좌표 → seq`·`좌표 → ETA` 표를 조회할 때 쓴다.
  StopKey? get key => point == null ? null : StopKey.of(point!);

  /// 명단을 정차 단위로 묶는다.
  ///
  /// [seqByStop] 은 노선에서 얻은 `좌표 → 정차 순번` 표다. 화면이 값으로 넘긴다 —
  /// 명단 상태 계층이 `routing` feature 를 직접 참조하지 않게 하기 위해서다
  /// (컨벤션 C-1, `DriverLocationCard(mockPath:)` 와 같은 방식).
  ///
  /// 좌표가 없는 학생은 묶을 근거가 없으므로 각자 한 그룹이 된다 —
  /// 남을 억지로 같은 정류장에 넣는 것보다 낫다.
  static List<RosterStopGroup> group(
    List<RosterStudent> students, {
    required DriveDirection direction,
    Map<StopKey, int>? seqByStop,
  }) {
    // 등장 순서를 보존해야 노선이 없을 때의 번호가 명단 순서와 맞는다.
    final order = <Object, int>{};
    final buckets = <Object, List<RosterStudent>>{};

    for (final (index, student) in students.indexed) {
      // 좌표가 없으면 학생 자신을 키로 써서 절대 다른 학생과 묶이지 않게 한다.
      final Object key = student.point == null
          ? _UngroupedKey(student.studentId)
          : StopKey.of(student.point!);
      order.putIfAbsent(key, () => index);
      buckets.putIfAbsent(key, () => []).add(student);
    }

    final keys = buckets.keys.toList()
      ..sort((a, b) {
        final seqA = seqByStop?[a];
        final seqB = seqByStop?[b];
        // 노선에 있는 정차가 항상 먼저 온다. 노선에 없는 정차(좌표 없음 등)는
        // 순서를 정할 근거가 없으므로 명단 등장 순으로 뒤에 붙인다.
        if (seqA != null && seqB != null) return seqA - seqB;
        if (seqA != null) return -1;
        if (seqB != null) return 1;
        return order[a]! - order[b]!;
      });

    // ⚠️ 노선에 없는 정차의 번호는 **이미 쓰인 순번 뒤에서** 이어 붙인다.
    //
    // 목록 위치(`index + 1`)를 그대로 쓰면 노선이 준 순번과 부딪친다. 노선이 어떤
    // 정차에 2번을 줬고 그 뒤에 노선에 없는 정차가 하나 붙으면 그 정차도 2번이
    // 되어, **지도에는 ②가 하나인데 명단에는 ②가 둘**이 된다. 이 화면의 존재
    // 이유가 "지도의 ②가 명단의 ②"라 그게 깨지면 기사가 엉뚱한 곳에서 아이를
    // 태운다. 노선 계산 뒤에 학생이 추가되거나 정류장이 미지정인 학생이 하나만
    // 있어도 재현된다.
    var lastSeq = 0;
    for (final key in keys) {
      final seq = seqByStop?[key];
      if (seq != null && seq > lastSeq) lastSeq = seq;
    }

    final groups = <RosterStopGroup>[];
    for (final key in keys) {
      // 노선이 아예 없으면 `lastSeq` 가 0 이라 1, 2, 3… 으로 매겨진다.
      final seq = seqByStop?[key] ?? ++lastSeq;
      groups.add(
        RosterStopGroup(
          seq: seq,
          students: buckets[key]!,
          direction: direction,
          label: buckets[key]!.first.location,
        ),
      );
    }
    return groups;
  }
}

/// 좌표가 없는 학생 전용 그룹 키. 학생 id 로만 같음을 판정한다.
class _UngroupedKey {
  const _UngroupedKey(this.studentId);

  final int studentId;

  @override
  bool operator ==(Object other) =>
      other is _UngroupedKey && other.studentId == studentId;

  @override
  int get hashCode => studentId.hashCode;
}
