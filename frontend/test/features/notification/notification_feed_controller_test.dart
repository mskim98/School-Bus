import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/api/api_client.dart';
import 'package:school_bus/core/ws/impl/stomp_gateway_impl.dart';
import 'package:school_bus/core/ws/spec/stomp_gateway.dart';
import 'package:school_bus/features/auth/application/auth_controller.dart';
import 'package:school_bus/features/notification/application/notification_feed_controller.dart';
import 'package:school_bus/features/notification/data/notification_repository.dart';
import 'package:school_bus/shared/domain/auth_session.dart';
import 'package:school_bus/shared/domain/role.dart';

/// REST 를 대신하는 어댑터. `api_client_test.dart` 와 같은 방식이다.
class _FakeAdapter implements HttpClientAdapter {
  String body = jsonEncode({'success': true, 'data': [], 'message': null});
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 소켓 없이 destination 별로 손수 밀어 넣는 게이트웨이.
class _FakeStompGateway implements StompGateway {
  final List<String> subscribedDestinations = [];
  final Map<String, StreamController<Map<String, dynamic>>> _feeds = {};
  final StreamController<StompConnectionState> _states =
      StreamController<StompConnectionState>.broadcast();

  int connectCalls = 0;
  int disconnectCalls = 0;

  StompConnectionState _state = const StompConnectionState(
    StompConnectionStatus.disconnected,
  );

  @override
  StompConnectionState get state => _state;

  @override
  Stream<StompConnectionState> get states => _states.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    emitState(const StompConnectionState(StompConnectionStatus.connected));
  }

  @override
  Future<void> disconnect() async => disconnectCalls++;

  @override
  Stream<Map<String, dynamic>> subscribe(String destination) {
    subscribedDestinations.add(destination);
    return (_feeds[destination] ??=
            StreamController<Map<String, dynamic>>.broadcast())
        .stream;
  }

  void emitState(StompConnectionState next) {
    _state = next;
    _states.add(next);
  }

  void push(String destination, Map<String, dynamic> payload) =>
      _feeds[destination]!.add(payload);

  Future<void> dispose() => _states.close();
}

Map<String, dynamic> notification({
  required int id,
  String type = 'BOARD_DONE',
  String message = '김민준 학생이 승차했습니다',
}) => {
  'id': id,
  'tenantId': 1,
  'studentId': 1,
  'type': type,
  'message': message,
  'createdAt': '2026-07-28T12:38:15.244186',
};

void main() {
  const tenantTopic = '/topic/tenant/1/notifications';
  const driverQueue = '/user/queue/notifications';

  late _FakeAdapter adapter;
  late _FakeStompGateway gateway;

  setUp(() {
    adapter = _FakeAdapter();
    gateway = _FakeStompGateway();
  });

  tearDown(() => gateway.dispose());

  /// 세션 역할에 맞춰 컨테이너를 만든다. autoDispose 라서 listen 으로 살려둔다.
  ProviderContainer containerFor(AuthSession session) {
    final dio = Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter;
    final repository = NotificationRepository(ApiClient(dio), gateway);

    final container = ProviderContainer(
      overrides: [
        currentSessionProvider.overrideWithValue(session),
        stompGatewayProvider.overrideWithValue(gateway),
        notificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    container.listen(notificationFeedControllerProvider, (_, _) {});
    return container;
  }

  AuthSession sessionOf(Role role, {int? tenantId}) => AuthSession(
    userId: 4,
    email: 'user@school.com',
    role: role,
    tenantId: tenantId,
  );

  group('학원 관리자', () {
    test('REST 이력을 먼저 채우고 학원 topic 을 구독한다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': [notification(id: 2), notification(id: 1)],
        'message': null,
      });

      final container = containerFor(sessionOf(Role.academyAdmin, tenantId: 1));
      final state = await container.read(
        notificationFeedControllerProvider.future,
      );

      expect(state.items.map((e) => e.id), [2, 1]);
      expect(gateway.subscribedDestinations, [tenantTopic]);
      expect(gateway.connectCalls, 1);
    });

    test('tenantId 를 쿼리에 싣지 않는다 — 서버가 본인 학원으로 처리한다', () async {
      final container = containerFor(sessionOf(Role.academyAdmin, tenantId: 1));
      await container.read(notificationFeedControllerProvider.future);

      expect(adapter.lastRequest!.path, '/api/notifications');
      expect(adapter.lastRequest!.queryParameters, isEmpty);
    });

    test('WebSocket 도착분이 맨 앞에 붙고 새 항목으로 표시된다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': [notification(id: 1)],
        'message': null,
      });

      final container = containerFor(sessionOf(Role.academyAdmin, tenantId: 1));
      await container.read(notificationFeedControllerProvider.future);

      gateway.push(tenantTopic, notification(id: 9, type: 'ROUTE_PUBLISHED'));
      await pumpEventQueue();

      final state = container.read(notificationFeedControllerProvider).value!;
      expect(state.items.map((e) => e.id), [9, 1]);
      expect(state.justArrivedIds, {9});
    });

    test('REST 이력과 id 가 겹치면 중복으로 넣지 않는다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': [notification(id: 5)],
        'message': null,
      });

      final container = containerFor(sessionOf(Role.academyAdmin, tenantId: 1));
      await container.read(notificationFeedControllerProvider.future);

      // 이력을 읽는 사이에 발생해 양쪽 경로로 다 들어오는 경우.
      gateway.push(tenantTopic, notification(id: 5));
      await pumpEventQueue();

      final state = container.read(notificationFeedControllerProvider).value!;
      expect(state.items.length, 1);
      expect(state.justArrivedIds, isEmpty);
    });

    test('새 항목 표시는 지울 수 있다', () async {
      final container = containerFor(sessionOf(Role.academyAdmin, tenantId: 1));
      await container.read(notificationFeedControllerProvider.future);

      gateway.push(tenantTopic, notification(id: 3));
      await pumpEventQueue();
      container
          .read(notificationFeedControllerProvider.notifier)
          .clearHighlights();

      final state = container.read(notificationFeedControllerProvider).value!;
      expect(state.items.length, 1);
      expect(state.justArrivedIds, isEmpty);
    });

    test('연결 상태 변화가 화면 상태에 실린다', () async {
      final container = containerFor(sessionOf(Role.academyAdmin, tenantId: 1));
      await container.read(notificationFeedControllerProvider.future);

      gateway.emitState(
        const StompConnectionState(
          StompConnectionStatus.reconnecting,
          message: null,
        ),
      );
      await pumpEventQueue();

      final state = container.read(notificationFeedControllerProvider).value!;
      expect(state.connection.status, StompConnectionStatus.reconnecting);
    });

    test('실시간 payload 가 계약과 다르면 목록은 유지한 채 오류만 알린다', () async {
      adapter.body = jsonEncode({
        'success': true,
        'data': [notification(id: 1)],
        'message': null,
      });

      final container = containerFor(sessionOf(Role.academyAdmin, tenantId: 1));
      await container.read(notificationFeedControllerProvider.future);

      gateway.push(tenantTopic, {'id': 2}); // 필수 필드가 빠진 payload
      await pumpEventQueue();

      final state = container.read(notificationFeedControllerProvider).value!;
      expect(state.items.length, 1);
      expect(state.liveError, isNotNull);
    });
  });

  group('플랫폼 관리자', () {
    test('소속이 없어 학원을 고정하고, 그 값을 쿼리에도 반드시 싣는다', () async {
      final container = containerFor(sessionOf(Role.platformAdmin));
      final state = await container.read(
        notificationFeedControllerProvider.future,
      );

      // 생략하면 400 이라 반드시 실어야 한다(MVP_API_SPEC §6.1).
      expect(adapter.lastRequest!.queryParameters, {'tenantId': 1});
      expect(gateway.subscribedDestinations, [tenantTopic]);
      expect(state.tenantId, 1);
      expect(state.isTenantPinned, isTrue);
    });
  });

  group('기사', () {
    test('개인 큐만 구독하고 학원 이력은 부르지 않는다', () async {
      final container = containerFor(sessionOf(Role.driver, tenantId: 1));
      final state = await container.read(
        notificationFeedControllerProvider.future,
      );

      // 학원 topic 은 관리자 전용이다 — 기사가 구독하면 세션까지 끊긴다(§7.3).
      expect(gateway.subscribedDestinations, [driverQueue]);
      expect(adapter.lastRequest, isNull);
      expect(state.items, isEmpty);
    });

    test('개인 큐로 온 알림도 목록에 쌓인다', () async {
      final container = containerFor(sessionOf(Role.driver, tenantId: 1));
      await container.read(notificationFeedControllerProvider.future);

      gateway.push(driverQueue, notification(id: 4, type: 'ROUTE_PUBLISHED'));
      await pumpEventQueue();

      final state = container.read(notificationFeedControllerProvider).value!;
      expect(state.items.single.type, 'ROUTE_PUBLISHED');
    });
  });

  test('화면을 벗어나면 연결을 정리한다', () async {
    final container = containerFor(sessionOf(Role.academyAdmin, tenantId: 1));
    await container.read(notificationFeedControllerProvider.future);

    container.dispose();
    await pumpEventQueue();

    expect(gateway.disconnectCalls, 1);
  });
}
