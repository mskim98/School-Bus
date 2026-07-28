import '../data/dto/ride_event_dto.dart';

/// 승하차 기록의 종류.
///
/// ⚠️ **하차와 인계는 다른 단계다.** 하원에서 아이가 버스에서 내린 것(`ALIGHT`)과
/// 보호자에게 넘긴 것(`HANDOVER`)은 책임이 갈리는 지점이라 서버도 따로 받는다.
enum RideEventType {
  board('BOARD', '승차'),
  alight('ALIGHT', '하차'),
  handover('HANDOVER', '인계완료');

  const RideEventType(this.wireName, this.label);

  /// 서버가 쓰는 값.
  final String wireName;

  /// 버튼에 그대로 쓰는 한글 이름.
  final String label;

  /// 모르는 값이면 null. 서버에 종류가 추가돼도 앱이 죽지 않게 한다.
  static RideEventType? fromWire(String? value) {
    for (final type in RideEventType.values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

/// 승하차 기록 한 건. 화면이 쓰는 모델.
class RideEvent {
  const RideEvent({
    required this.id,
    required this.studentId,
    required this.type,
    required this.occurredAt,
  });

  final int id;
  final int studentId;

  /// 서버가 **실제로 기록한** 종류. 화면은 요청값이 아니라 이 값으로 상태를 옮긴다
  /// (낙관적 갱신 금지 — 계획서 §5.4).
  final RideEventType type;

  final DateTime occurredAt;

  /// 모르는 종류(`fromWire` 실패)면 null 을 돌려준다.
  /// 어느 단계인지 모르는 기록으로 학생 상태를 함부로 옮기지 않기 위해서다.
  static RideEvent? fromDto(RideEventDto dto) {
    final type = RideEventType.fromWire(dto.type);
    if (type == null) return null;
    return RideEvent(
      id: dto.id,
      studentId: dto.studentId,
      type: type,
      occurredAt: DateTime.parse(dto.occurredAt),
    );
  }
}
