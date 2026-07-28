import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/notification/data/dto/notification_dto.dart';

void main() {
  Map<String, dynamic> payload({
    Object? studentId = 1,
    String type = 'BOARD_DONE',
    String createdAt = '2026-07-22T08:05:00',
  }) => {
    'id': 7,
    'tenantId': 1,
    'studentId': studentId,
    'type': type,
    'message': '김민준 학생이 승차했습니다',
    'createdAt': createdAt,
  };

  test('REST 응답을 그대로 읽는다', () {
    final dto = NotificationDto.fromJson(payload());

    expect(dto.id, 7);
    expect(dto.tenantId, 1);
    expect(dto.studentId, 1);
    expect(dto.type, 'BOARD_DONE');
    expect(dto.message, '김민준 학생이 승차했습니다');
    expect(dto.createdAt, DateTime(2026, 7, 22, 8, 5));
  });

  test('WebSocket 이 주는 나노초(9자리) 시각도 그대로 파싱된다', () {
    // REST 는 마이크로초(6자리), WS 는 나노초(9자리)로 온다 — 실측 확인(2026-07-28).
    final rest = NotificationDto.fromJson(
      payload(createdAt: '2026-07-28T12:38:15.244186'),
    );
    final ws = NotificationDto.fromJson(
      payload(createdAt: '2026-07-28T12:38:15.244186428'),
    );

    expect(ws.createdAt, rest.createdAt);
  });

  test('타임존이 없으므로 로컬 시각으로 읽는다', () {
    final dto = NotificationDto.fromJson(payload());

    expect(dto.createdAt.isUtc, isFalse);
  });

  test('studentId 가 없는 알림도 받는다', () {
    final dto = NotificationDto.fromJson(payload(studentId: null));

    expect(dto.studentId, isNull);
  });

  test('모르는 type 이 와도 파싱이 깨지지 않는다 — 서버에 종류가 추가될 수 있다', () {
    final dto = NotificationDto.fromJson(payload(type: 'SOMETHING_NEW'));

    expect(dto.type, 'SOMETHING_NEW');
  });
}
