import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../../../core/ws/spec/stomp_gateway.dart';
import 'dto/notification_dto.dart';

/// 알림 조회 — REST 이력 + WebSocket 실시간, **두 경로를 한 곳에 모은다.**
///
/// 둘을 한 클래스에 둔 이유: 화면 입장에서 "알림을 가져온다"는 하나의 일이고,
/// 서버가 REST 와 WS 로 **같은 `NotificationResponse`** 를 주기 때문이다. 나누면
/// 같은 계약을 두 군데서 알게 된다.
///
/// 서버가 하나뿐이라 포트로 나누지 않는다(컨벤션 §5).
class NotificationRepository {
  const NotificationRepository(this._client, this._gateway);

  final ApiClient _client;
  final StompGateway _gateway;

  /// 기사 본인에게 배달되는 큐. Spring 의 user-destination 라우팅이 세션 단위로
  /// 격리해 주므로 별도 인가 검사가 없다(§7.3).
  static const _driverQueue = '/user/queue/notifications';

  /// 학원 전체 broadcast. ⚠️ **추가 인가 검사가 있다** — 그 학원 관리자이거나
  /// `PLATFORM_ADMIN` 이 아니면 SUBSCRIBE 자체가 거부되고 **연결까지 끊긴다**(실측).
  static String _tenantTopic(int tenantId) =>
      '/topic/tenant/$tenantId/notifications';

  /// 학원 알림 이력(최신순). 빈 배열은 에러가 아니다(컨벤션 §7-4).
  ///
  /// [tenantId] 는 `ACADEMY_ADMIN` 이면 **생략**한다(서버가 본인 학원으로 처리).
  /// `PLATFORM_ADMIN` 은 **필수**이며, 빠지면 400 이다(MVP_API_SPEC §6.1).
  Future<List<NotificationDto>> getTenantHistory({int? tenantId}) {
    return _client.get(
      '/api/notifications',
      query: {'tenantId': tenantId},
      decode: Decode.list(NotificationDto.fromJson),
    );
  }

  /// 학원 실시간 알림. 구독 시작 **이후** 발생분만 온다 — 이력은 [getTenantHistory] 로 채운다.
  Stream<NotificationDto> watchTenant(int tenantId) =>
      _gateway.subscribe(_tenantTopic(tenantId)).map(NotificationDto.fromJson);

  /// 기사 실시간 알림(자기 반 학생 관련).
  Stream<NotificationDto> watchMine() =>
      _gateway.subscribe(_driverQueue).map(NotificationDto.fromJson);
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(
    ref.watch(apiClientProvider),
    ref.watch(stompGatewayProvider),
  ),
);
