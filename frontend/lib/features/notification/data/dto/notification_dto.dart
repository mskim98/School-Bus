/// `NotificationResponse` — 서버 표현 그대로.
///
/// REST(`GET /api/notifications`)와 WebSocket(`/topic/tenant/{id}/notifications`)이
/// **완전히 같은 모양**으로 준다(MVP_API_SPEC §6.1·§7.3). 그래서 두 경로의 결과를
/// 한 목록에 그대로 섞을 수 있다.
///
/// 화면이 쓰기에 부족함이 없어 domain 모델을 따로 만들지 않는다(컨벤션 §4 — "만들지 않는 경우").
class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.tenantId,
    required this.studentId,
    required this.type,
    required this.message,
    required this.createdAt,
  });

  /// 중복 판정 키. REST 이력과 WS 도착분이 겹칠 수 있어 화면이 이 값으로 걸러낸다.
  final int id;

  final int tenantId;

  /// 학생과 무관한 알림(노선 배포 등)에도 값이 실려 오지만, 계약상 보장되진 않아 nullable 로 둔다.
  final int? studentId;

  /// `BOARD_DONE`·`ALIGHT_DONE`·`HANDOVER_DONE`·`APPROACH`·`NO_SHOW`·`SOS`·
  /// `SCHEDULE_RESULT`·`CONNECTION_LOST`·`ROUTE_RECOMMENDED`·`ROUTE_PUBLISHED`
  ///
  /// enum 으로 좁히지 않는다 — 서버에 종류가 추가돼도 목록이 통째로 파싱 실패하면 안 된다.
  final String type;

  /// 사용자에게 **그대로** 보여주는 문구. 앱이 다시 쓰지 않는다(컨벤션 §7-2).
  final String message;

  /// ⚠️ 타임존이 없는 `LocalDateTime` 문자열이다 — 서버 로컬시각을 그대로 표시한다.
  ///
  /// 소수점 자릿수가 경로마다 다르다: REST 는 마이크로초(6자리), WS 는 나노초(9자리).
  /// `DateTime.parse` 가 초과 자릿수를 잘라내므로 둘 다 그대로 통과한다(2026-07-28 실측).
  final DateTime createdAt;

  static NotificationDto fromJson(Map<String, dynamic> json) => NotificationDto(
    id: (json['id'] as num).toInt(),
    tenantId: (json['tenantId'] as num).toInt(),
    studentId: (json['studentId'] as num?)?.toInt(),
    type: json['type'] as String,
    // 기본값으로 때우지 않는다(컨벤션 C-2) — 문구가 없는 알림은 보여줄 게 없어서,
    // 빈 줄을 그리느니 계약 위반으로 드러나는 편이 낫다.
    message: json['message'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
