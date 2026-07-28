/// 노선 계획의 승인 단계.
///
/// 서버 전이 순서는 `DRAFT → RECOMMENDED → APPROVED → PUBLISHED` 이고,
/// 기사에게 노출되는 건 [published] 뿐이다.
///
/// 기사 화면(C6)은 PUBLISHED 만 받으므로 이 값을 볼 일이 없지만, 관리자 화면은
/// "제안된 것"과 "이미 배포된 것"을 구분해야 해서 도메인까지 끌어올린다.
enum RoutePlanStatus {
  draft('DRAFT', '초안'),
  recommended('RECOMMENDED', '제안됨'),
  approved('APPROVED', '승인됨'),
  published('PUBLISHED', '배포됨');

  const RoutePlanStatus(this.wireName, this.label);

  /// 서버가 쓰는 문자열
  final String wireName;

  /// 화면에 보여줄 한글 이름
  final String label;

  /// 모르는 값이면 null — 서버에 상태가 추가돼도 앱이 죽지 않게 한다.
  static RoutePlanStatus? fromWire(String? value) {
    for (final status in RoutePlanStatus.values) {
      if (status.wireName == value) return status;
    }
    return null;
  }

  /// 확정(`auto-assign/confirm`)을 서버가 받아주는 단계인가.
  ///
  /// 서버는 승인 단계에서 DRAFT·RECOMMENDED 만 허용하고 나머지는 **409** 로 막는다
  /// (`RoutePlan.approve`). 이미 확정된 계획을 다시 보내지 않도록 화면에서 먼저 걸러낸다.
  bool get isConfirmable =>
      this == RoutePlanStatus.draft || this == RoutePlanStatus.recommended;

  /// 기사에게 노출되는 상태인가.
  bool get isPublished => this == RoutePlanStatus.published;
}
