/// 실시간(STOMP over WebSocket) 게이트웨이 포트.
///
/// 포트로 둔 이유(컨벤션 §5) — 테스트에서 실제 소켓을 띄울 수 없어 Fake 로 갈아끼워야 한다.
/// 덕분에 `application`·`presentation` 은 `stomp_dart_client` 를 import 하지 않는다(§8).
///
/// **JSON 을 여기까지만 다룬다.** 이 포트는 파싱된 `Map` 을 돌려주고, DTO 변환은
/// feature 의 repository 가 한다(§4) — core 는 어떤 feature 가 뭘 구독하는지 모른다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 연결 상태. 화면이 "지금 실시간이 살아 있나"를 표시하는 데 쓴다.
enum StompConnectionStatus {
  /// 연결한 적이 없거나 스스로 끊었다. 재시도도 하지 않는 상태.
  disconnected,

  /// 첫 연결 시도 중.
  connecting,

  /// 세션 수립 완료. 이 시점 **이후의** 메시지만 받는다.
  connected,

  /// 연결이 끊겨 자동 재시도 중.
  reconnecting,
}

/// 연결 상태 + 마지막 실패 사유.
///
/// 사유를 상태와 함께 묶어 두는 이유 — 화면이 "끊김"만 보여주면 사용자가 할 수 있는
/// 행동이 없다. 무엇 때문에 끊겼는지까지 있어야 재시도/재로그인을 안내할 수 있다.
class StompConnectionState {
  const StompConnectionState(this.status, {this.message});

  final StompConnectionStatus status;

  /// 사용자에게 보여줄 한글 사유. 정상 상태면 null.
  final String? message;

  bool get isLive => status == StompConnectionStatus.connected;

  @override
  String toString() => 'StompConnectionState($status, message: $message)';
}

abstract interface class StompGateway {
  /// 지금 상태(동기 조회용).
  StompConnectionState get state;

  /// 상태 변화 스트림. 여러 화면이 함께 구독할 수 있어야 하므로 broadcast 다.
  Stream<StompConnectionState> get states;

  /// 세션을 연다. 이미 열려 있으면 아무 일도 하지 않는다.
  ///
  /// 인증 토큰은 구현체가 **연결할 때마다 저장소에서 새로 읽는다** — 재연결 시점에
  /// 이전 토큰이 이미 만료됐을 수 있기 때문이다.
  Future<void> connect();

  /// 세션을 닫고 자동 재연결도 멈춘다. 화면을 벗어날 때 반드시 호출한다(누수 방지).
  Future<void> disconnect();

  /// [destination] 을 구독한다. **스트림을 listen 하는 순간** SUBSCRIBE 가 나가고,
  /// 구독을 취소하면 UNSUBSCRIBE 가 나간다.
  ///
  /// 아직 연결 전이라도 호출할 수 있다 — 연결되는 즉시(그리고 재연결될 때마다)
  /// 구현체가 알아서 다시 구독한다. STOMP 는 재연결하면 세션이 완전히 새로 생기므로
  /// 이전 구독이 살아남지 않는다.
  Stream<Map<String, dynamic>> subscribe(String destination);
}

/// ⚠️ `bootstrap()` 에서 override 해야 하는 provider.
///
/// **provider 선언이 구현체 파일이 아니라 여기 있는 이유**(컨벤션 §5) —
/// 구현체 파일에 두면 소비자가 `impl/...` 을 import 하게 되고, 그러면 구현을 갈아끼울 때
/// 호출부를 전부 고쳐야 한다. 포트를 만든 목적 자체가 사라진다.
///
/// 특히 이 포트는 조립에 필요한 재료(서버 URL·토큰 저장소·재발급 경로·dispose)가 많은데,
/// 그 조립 지식은 인터페이스가 아니라 **합성 지점의 몫**이다.
final stompGatewayProvider = Provider<StompGateway>(
  (ref) => throw UnimplementedError(
    'stompGatewayProvider 를 bootstrap() 에서 override 해야 합니다',
  ),
);
