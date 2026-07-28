import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/storage/spec/token_storage.dart';
import 'package:school_bus/core/ws/impl/stomp_gateway_impl.dart';
import 'package:school_bus/core/ws/spec/stomp_gateway.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

/// 실제 소켓 대신 콜백을 손으로 때리는 가짜 클라이언트.
///
/// 이걸 끼울 수 있게 [StompGatewayImpl] 이 `clientFactory` 를 받는다 —
/// 재연결·토큰 재주입 같은 "네트워크가 끊겨야 확인되는" 동작은 이 방법으로만 검증할 수 있다.
class _FakeStompClient implements StompClient {
  _FakeStompClient(this.config);

  @override
  final StompConfig config;

  bool activated = false;
  bool deactivated = false;

  final List<String> subscribed = [];
  final List<String> unsubscribed = [];
  final Map<String, StompFrameCallback> _callbacks = {};

  bool _connected = false;

  @override
  bool get connected => _connected;

  @override
  bool get isActive => activated && !deactivated;

  @override
  void activate() => activated = true;

  @override
  void deactivate() {
    deactivated = true;
    _connected = false;
  }

  @override
  StompUnsubscribe subscribe({
    required String destination,
    required StompFrameCallback callback,
    Map<String, String>? headers,
  }) {
    subscribed.add(destination);
    _callbacks[destination] = callback;
    return ({Map<String, String>? unsubscribeHeaders}) =>
        unsubscribed.add(destination);
  }

  @override
  void send({
    required String destination,
    Map<String, String>? headers,
    String? body,
    Uint8List? binaryBody,
  }) {}

  @override
  void ack({required String id, Map<String, String>? headers}) {}

  @override
  void nack({required String id, Map<String, String>? headers}) {}

  // ── 서버 흉내 ──

  /// CONNECT 성공. 라이브러리와 같은 순서로 `beforeConnect` 를 먼저 await 한다.
  Future<void> serverAccepts() async {
    await config.beforeConnect();
    _connected = true;
    config.onConnect(StompFrame(command: 'CONNECTED'));
  }

  void serverClosesSocket() {
    _connected = false;
    config.onWebSocketDone();
  }

  void serverSendsError(String message) {
    config.onStompError(
      StompFrame(command: 'ERROR', headers: {'message': message}),
    );
  }

  void serverPushes(String destination, String body) {
    _callbacks[destination]!(
      StompFrame(
        command: 'MESSAGE',
        headers: {'destination': destination},
        body: body,
      ),
    );
  }

  /// CONNECT 프레임에 실릴 헤더 — 라이브러리가 전송 직전에 읽는 바로 그 맵이다.
  Map<String, String> get connectHeaders => config.stompConnectHeaders!;
}

class _FakeTokenStorage implements TokenStorage {
  String? accessToken;
  int readCount = 0;

  @override
  Future<String?> readAccessToken() async {
    readCount++;
    return accessToken;
  }

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  late _FakeTokenStorage storage;
  late _FakeStompClient client;
  late StompGatewayImpl gateway;
  late int refreshCalls;

  setUp(() {
    storage = _FakeTokenStorage()..accessToken = 'token-1';
    refreshCalls = 0;
    gateway = StompGatewayImpl(
      url: 'ws://test/ws/location',
      tokenStorage: storage,
      refreshTokens: () async {
        refreshCalls++;
        storage.accessToken = 'token-refreshed';
        return true;
      },
      clientFactory: (config) => client = _FakeStompClient(config),
    );
  });

  tearDown(() => gateway.dispose());

  group('CONNECT 인증 헤더', () {
    test('연결할 때 저장된 accessToken 을 Bearer 로 싣는다', () async {
      await gateway.connect();
      await client.serverAccepts();

      expect(client.connectHeaders['Authorization'], 'Bearer token-1');
    });

    test('토큰이 없으면 Authorization 헤더를 아예 붙이지 않는다', () async {
      storage.accessToken = null;

      await gateway.connect();
      await client.serverAccepts();

      expect(client.connectHeaders.containsKey('Authorization'), isFalse);
    });

    test('재연결할 때 토큰을 다시 읽어 새 값으로 갈아끼운다', () async {
      await gateway.connect();
      await client.serverAccepts();
      expect(client.connectHeaders['Authorization'], 'Bearer token-1');

      // 세션이 살아 있는 동안 토큰이 갱신된 상황(15분 만료 → 재발급).
      storage.accessToken = 'token-2';
      client.serverClosesSocket();
      await client.serverAccepts();

      expect(client.connectHeaders['Authorization'], 'Bearer token-2');
      // 캐시해두지 않고 매번 저장소를 읽었는지까지 확인한다.
      expect(storage.readCount, 2);
    });

    test('CONNECTED 전에 끊기면 다음 시도 전에 토큰 재발급을 먼저 한다', () async {
      await gateway.connect();

      client.serverClosesSocket(); // 인증 거부로 붙지도 못한 경우
      await client.serverAccepts();

      expect(refreshCalls, 1);
      expect(client.connectHeaders['Authorization'], 'Bearer token-refreshed');
    });

    test('붙었다가 끊긴 경우에는 재발급하지 않는다', () async {
      await gateway.connect();
      await client.serverAccepts();

      client.serverClosesSocket();
      await client.serverAccepts();

      expect(refreshCalls, 0);
    });
  });

  group('구독', () {
    const destination = '/topic/tenant/1/notifications';

    test('listen 하는 순간 SUBSCRIBE 가 나간다', () async {
      await gateway.connect();
      await client.serverAccepts();

      final sub = gateway.subscribe(destination).listen((_) {});
      addTearDown(sub.cancel);

      expect(client.subscribed, [destination]);
    });

    test('연결 전에 구독해도 연결되는 순간 SUBSCRIBE 된다', () async {
      final sub = gateway.subscribe(destination).listen((_) {});
      addTearDown(sub.cancel);

      await gateway.connect();
      await client.serverAccepts();

      expect(client.subscribed, [destination]);
    });

    test('재연결하면 구독을 다시 건다 — STOMP 는 세션이 새로 생겨 이전 구독이 없다', () async {
      final sub = gateway.subscribe(destination).listen((_) {});
      addTearDown(sub.cancel);

      await gateway.connect();
      await client.serverAccepts();
      client.serverClosesSocket();
      await client.serverAccepts();

      expect(client.subscribed, [destination, destination]);
    });

    test('구독을 취소하면 UNSUBSCRIBE 하고 재연결해도 다시 걸지 않는다', () async {
      final sub = gateway.subscribe(destination).listen((_) {});
      await gateway.connect();
      await client.serverAccepts();

      await sub.cancel();
      expect(client.unsubscribed, [destination]);

      client.serverClosesSocket();
      await client.serverAccepts();
      expect(client.subscribed, [destination]);
    });

    test('메시지 본문을 JSON Map 으로 풀어 전달한다', () async {
      await gateway.connect();
      await client.serverAccepts();

      final received = <Map<String, dynamic>>[];
      final sub = gateway.subscribe(destination).listen(received.add);
      addTearDown(sub.cancel);

      client.serverPushes(
        destination,
        jsonEncode({'id': 7, 'type': 'BOARD_DONE'}),
      );
      await pumpEventQueue();

      expect(received.single['id'], 7);
      expect(received.single['type'], 'BOARD_DONE');
    });

    test('JSON 이 아닌 본문은 삼키지 않고 스트림 에러로 올린다', () async {
      await gateway.connect();
      await client.serverAccepts();

      Object? error;
      final sub = gateway
          .subscribe(destination)
          .listen((_) {}, onError: (Object e) => error = e);
      addTearDown(sub.cancel);

      client.serverPushes(destination, 'not json');
      await pumpEventQueue();

      expect(error, isA<FormatException>());
    });
  });

  group('연결 상태', () {
    test('connect → connecting → connected 로 넘어간다', () async {
      expect(gateway.state.status, StompConnectionStatus.disconnected);

      await gateway.connect();
      expect(gateway.state.status, StompConnectionStatus.connecting);

      await client.serverAccepts();
      expect(gateway.state.status, StompConnectionStatus.connected);
    });

    test('끊기면 reconnecting 이 된다', () async {
      await gateway.connect();
      await client.serverAccepts();

      client.serverClosesSocket();

      expect(gateway.state.status, StompConnectionStatus.reconnecting);
    });

    test('disconnect 하면 클라이언트를 내리고 disconnected 가 된다', () async {
      await gateway.connect();
      await client.serverAccepts();

      await gateway.disconnect();

      expect(client.deactivated, isTrue);
      expect(gateway.state.status, StompConnectionStatus.disconnected);
    });

    test('상태 변화가 스트림으로도 나간다', () async {
      final seen = <StompConnectionStatus>[];
      final sub = gateway.states.listen((s) => seen.add(s.status));
      addTearDown(sub.cancel);

      await gateway.connect();
      await client.serverAccepts();
      await pumpEventQueue();

      expect(seen, [
        StompConnectionStatus.connecting,
        StompConnectionStatus.connected,
      ]);
    });
  });

  group('재시도해도 소용없는 실패는 접는다', () {
    test('구독 인가 거부(CONNECTED 이후 ERROR)면 재시도를 멈춘다', () async {
      await gateway.connect();
      await client.serverAccepts();

      client.serverSendsError(
        'Failed to send message to ...clientInboundChannel',
      );

      expect(client.deactivated, isTrue);
      expect(gateway.state.status, StompConnectionStatus.disconnected);
      // 서버가 준 Spring 내부 문구를 그대로 노출하지 않는다.
      expect(gateway.state.message, '실시간 알림을 구독할 권한이 없습니다');
    });

    test('연속 실패가 한계를 넘으면 자동 재연결을 포기한다', () async {
      await gateway.connect();

      for (var i = 0; i < 5; i++) {
        client.serverClosesSocket();
      }

      expect(gateway.state.status, StompConnectionStatus.disconnected);
      expect(gateway.state.message, isNotNull);
      expect(client.deactivated, isTrue);
    });
  });
}
