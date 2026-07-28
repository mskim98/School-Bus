// ignore_for_file: prefer_initializing_formals
//
// `auth_interceptor.dart` 와 같은 이유다 — Dart 는 **명명 매개변수를 private 으로 만들 수
// 없어서**(`{required this._url}` 은 컴파일 에러) 이 규칙을 만족시킬 방법이 없다.
// 호출부 가독성을 위해 명명 매개변수를 유지하고 규칙만 끈다.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

// 타입은 포트(spec)만 쓴다. 이 import 는 `tokenStorageProvider` 배선 때문이며,
// `api_client.dart` 도 같은 이유로 같은 파일을 가리킨다.
import '../../storage/spec/token_storage.dart';
import '../spec/stomp_gateway.dart';

/// [StompClient] 를 만드는 함수. 테스트가 가짜 클라이언트를 끼우는 유일한 이음매다.
typedef StompClientFactory = StompClient Function(StompConfig config);

/// `stomp_dart_client` 기반 구현. **이 파일 밖으로 STOMP 타입이 새지 않는다.**
///
/// 서버 규약(MVP_API_SPEC §7):
///  - endpoint `ws://<host>/ws/location`, **SockJS 미사용**(순수 STOMP)
///  - 인증은 `CONNECT` 프레임의 네이티브 헤더 `Authorization: Bearer <token>` **1회**만 검증
///  - heartbeat 10초
///  - 재연결은 100% 클라이언트 책임
///
/// ⚠️ **이 클래스가 풀어야 하는 함정 세 가지**
///
/// 1. **재연결 때마다 토큰을 다시 실어야 한다.** 서버는 재연결을 새 세션으로 취급해
///    이전 인증을 재사용하지 않는다. accessToken 수명이 15분이라 재연결 시점엔 이미
///    만료됐을 수 있으므로 **저장소에서 매번 새로 읽는다**([_prepareConnect]).
/// 2. **재연결하면 구독이 전부 날아간다.** 그래서 등록된 구독을 [_subscriptions] 에
///    들고 있다가 CONNECT 성공마다 다시 SUBSCRIBE 한다.
/// 3. **실패를 무한 재시도하면 안 된다.** 인가가 거부된 구독(`/topic/tenant/{남의 학원}`)은
///    다시 붙어도 똑같이 거부되므로 서버만 두들기게 된다 — 재시도해서 될 실패와
///    아닌 실패를 갈라서 처리한다([_onStompError]).
class StompGatewayImpl implements StompGateway {
  StompGatewayImpl({
    required String url,
    required TokenStorage tokenStorage,
    required Future<bool> Function() refreshTokens,
    StompClientFactory? clientFactory,
  }) : _url = url,
       _tokenStorage = tokenStorage,
       _refreshTokens = refreshTokens,
       _clientFactory =
           clientFactory ?? ((config) => StompClient(config: config));

  final String _url;
  final TokenStorage _tokenStorage;
  final Future<bool> Function() _refreshTokens;
  final StompClientFactory _clientFactory;

  /// 서버가 정한 heartbeat 주기(§7.1 `app.connection.heartbeat-ms` = 10000).
  static const _heartbeat = Duration(seconds: 10);

  /// 재연결 간격. 서버 끊김 판정 유예(30초)보다 충분히 짧아야 `CONNECTION_LOST`
  /// 오탐을 피할 수 있다.
  static const _reconnectDelay = Duration(seconds: 3);

  /// 연속 실패를 이만큼 넘기면 자동 재시도를 접는다.
  /// 무한 재시도는 화면에는 "재연결 중"만 계속 보이고 서버만 두들기는 최악의 조합이다.
  static const _maxConsecutiveFailures = 5;

  static const _authorizationHeader = 'Authorization';

  /// ⚠️ **일부러 mutable 이고, [StompConfig] 에 이 인스턴스를 그대로 넘긴다.**
  ///
  /// `stomp_dart_client` 는 CONNECT 프레임을 만들 때 `config.stompConnectHeaders` 를
  /// 그때그때 읽고(`StompHandler._connectToStomp`), 재연결 직전에 `beforeConnect` 를
  /// await 한다. 즉 이 맵을 `beforeConnect` 안에서 갈아끼우면 **재연결마다 새 토큰이
  /// 실린다.** config 를 새로 만들 방법이 없어서(클라이언트가 최초 config 를 붙들고 있다)
  /// 이 방식이 유일한 경로다.
  final Map<String, String> _connectHeaders = {};

  final List<_Subscription> _subscriptions = [];
  final StreamController<StompConnectionState> _states =
      StreamController<StompConnectionState>.broadcast();

  StompClient? _client;
  StompConnectionState _state = const StompConnectionState(
    StompConnectionStatus.disconnected,
  );

  /// 이번 연결 시도가 CONNECTED 까지 갔는가. "인증 실패"와 "붙었다 끊김"을 가른다.
  bool _reachedConnected = false;

  /// 다음 CONNECT 전에 토큰 재발급을 먼저 할지. 인증 실패로 끊긴 뒤에만 켠다.
  bool _needsTokenRefresh = false;

  int _consecutiveFailures = 0;
  bool _disposed = false;

  @override
  StompConnectionState get state => _state;

  @override
  Stream<StompConnectionState> get states => _states.stream;

  @override
  Future<void> connect() async {
    if (_disposed || _client != null) return;

    _consecutiveFailures = 0;
    _needsTokenRefresh = false;
    _emit(const StompConnectionState(StompConnectionStatus.connecting));

    _client = _clientFactory(
      StompConfig(
        url: _url,
        // SockJS 를 쓰지 않는다 — 서버가 순수 STOMP 엔드포인트다(§7.1).
        useSockJS: false,
        reconnectDelay: _reconnectDelay,
        heartbeatIncoming: _heartbeat,
        heartbeatOutgoing: _heartbeat,
        stompConnectHeaders: _connectHeaders,
        beforeConnect: _prepareConnect,
        onConnect: _onConnect,
        onWebSocketDone: _onSocketClosed,
        onWebSocketError: _onSocketError,
        onStompError: _onStompError,
        onDebugMessage: _debug,
      ),
    )..activate();
  }

  @override
  Future<void> disconnect() async {
    final client = _client;
    _client = null;
    _reachedConnected = false;
    for (final sub in _subscriptions) {
      sub.unsubscribe = null;
    }
    client?.deactivate();
    _emit(const StompConnectionState(StompConnectionStatus.disconnected));
  }

  @override
  Stream<Map<String, dynamic>> subscribe(String destination) {
    late final _Subscription sub;
    final controller = StreamController<Map<String, dynamic>>(
      onListen: () => _register(sub),
      onCancel: () => _unregister(sub),
    );
    sub = _Subscription(destination: destination, controller: controller);
    return controller.stream;
  }

  /// provider 가 폐기될 때 호출한다. 이후 [connect] 는 아무 일도 하지 않는다.
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _states.close();
  }

  // ── 연결 수명주기 ────────────────────────────────────────────────

  /// CONNECT 직전마다 불린다(최초 연결·재연결 모두).
  ///
  /// 토큰을 **여기서** 읽는 게 핵심이다. 생성 시점에 한 번 읽어두면 15분 뒤 재연결에서
  /// 만료된 토큰을 그대로 다시 보내 영영 붙지 못한다.
  Future<void> _prepareConnect() async {
    if (_needsTokenRefresh) {
      _needsTokenRefresh = false;
      // 실패해도 계속 진행한다 — 어차피 CONNECT 가 거부되면서 상태로 드러나고,
      // 여기서 예외를 던지면 라이브러리가 재연결 자체를 멈춘다.
      await _refreshTokens();
    }

    final token = await _tokenStorage.readAccessToken();
    _connectHeaders.remove(_authorizationHeader);
    if (token != null && token.isNotEmpty) {
      _connectHeaders[_authorizationHeader] = 'Bearer $token';
    }
  }

  void _onConnect(StompFrame _) {
    _reachedConnected = true;
    _consecutiveFailures = 0;
    _emit(const StompConnectionState(StompConnectionStatus.connected));

    // 재연결이면 이전 세션의 구독은 이미 사라졌다. 전부 다시 건다.
    for (final sub in _subscriptions) {
      _bind(sub);
    }
  }

  /// 소켓이 닫혔다. 라이브러리가 [_reconnectDelay] 뒤 자동으로 다시 붙는다.
  void _onSocketClosed() {
    for (final sub in _subscriptions) {
      sub.unsubscribe = null;
    }
    if (_client == null) return; // 우리가 끊은 경우 — 상태는 이미 disconnected 다.

    // CONNECTED 도 못 갔다면 인증 실패일 가능성이 높다 → 다음 시도 전에 재발급.
    if (!_reachedConnected) _needsTokenRefresh = true;
    _reachedConnected = false;

    _consecutiveFailures++;
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      _giveUp('실시간 연결에 반복해서 실패했습니다. 다시 시도해 주세요');
      return;
    }
    _emit(const StompConnectionState(StompConnectionStatus.reconnecting));
  }

  void _onSocketError(dynamic error) {
    _debug('websocket error: $error');
  }

  /// 서버가 보낸 STOMP `ERROR` 프레임. 서버는 이걸 보낸 뒤 소켓을 닫는다.
  ///
  /// 내용은 Spring 내부 문구(`Failed to send message to ...clientInboundChannel`)라
  /// 사용자에게 보여줄 수 없다 — 그래서 **상황으로 갈라** 우리 문구를 쓴다(컨벤션 §7-1과
  /// 같은 이유: 서버 문자열에 기대지 않는다).
  void _onStompError(StompFrame frame) {
    _debug('stomp error: ${frame.headers['message']}');

    if (_reachedConnected) {
      // 인증은 통과했는데 거부됐다 = 구독 인가 실패(남의 학원 topic 등).
      // 다시 붙어도 결과가 같으므로 재시도하지 않는다.
      _giveUp('실시간 알림을 구독할 권한이 없습니다');
      return;
    }
    // CONNECT 단계에서 거부 = 토큰 문제. 재발급하고 재시도해 볼 값어치가 있다.
    _needsTokenRefresh = true;
  }

  /// 자동 재시도를 접고 사유를 남긴다. 다시 붙이려면 화면이 [connect] 를 다시 부른다.
  void _giveUp(String reason) {
    final client = _client;
    _client = null;
    _reachedConnected = false;
    client?.deactivate();
    _emit(
      StompConnectionState(StompConnectionStatus.disconnected, message: reason),
    );
  }

  // ── 구독 관리 ────────────────────────────────────────────────────

  void _register(_Subscription sub) {
    _subscriptions.add(sub);
    if (_state.isLive) _bind(sub);
  }

  void _unregister(_Subscription sub) {
    _subscriptions.remove(sub);
    sub.unsubscribe?.call();
    sub.unsubscribe = null;
  }

  void _bind(_Subscription sub) {
    final client = _client;
    if (client == null) return;
    sub.unsubscribe = client.subscribe(
      destination: sub.destination,
      callback: (frame) => _deliver(sub, frame),
    );
  }

  void _deliver(_Subscription sub, StompFrame frame) {
    if (sub.controller.isClosed) return;
    final body = frame.body;
    if (body == null || body.isEmpty) return;

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('객체를 기대했지만 ${decoded.runtimeType} 를 받았습니다');
      }
      sub.controller.add(decoded);
    } on FormatException catch (e, stack) {
      // 삼키지 않는다(컨벤션 §7-5) — 계약이 어긋난 건 화면이 알아야 한다.
      sub.controller.addError(e, stack);
    }
  }

  void _emit(StompConnectionState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  void _debug(String message) {
    if (kDebugMode) debugPrint('[stomp] $message');
  }
}

/// 등록된 구독 하나. 재연결 때마다 [unsubscribe] 는 무효가 되고 다시 채워진다.
class _Subscription {
  _Subscription({required this.destination, required this.controller});

  final String destination;
  final StreamController<Map<String, dynamic>> controller;
  StompUnsubscribe? unsubscribe;
}

/// 앱 전역 게이트웨이.
///
/// 연결 수명은 **쓰는 쪽(application)** 이 정한다 — 화면을 벗어나면
/// [StompGateway.disconnect] 를 불러 소켓을 닫는다.
