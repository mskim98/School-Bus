import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ws/spec/stomp_gateway.dart';
import '../../../shared/domain/auth_session.dart';
import '../../../shared/domain/role.dart';
import '../../auth/application/auth_controller.dart';
import '../data/dto/notification_dto.dart';
import '../data/notification_repository.dart';

/// 알림함 상태 — **REST 이력 + WebSocket 도착분**을 한 목록으로 합친 결과.
///
/// 순서는 항상 최신순이다(서버 이력이 최신순으로 오고, 새 도착분은 맨 앞에 붙인다).
class NotificationFeedState {
  const NotificationFeedState({
    this.items = const [],
    this.justArrivedIds = const {},
    this.connection = const StompConnectionState(
      StompConnectionStatus.disconnected,
    ),
    this.tenantId,
    this.isTenantPinned = false,
    this.liveError,
  });

  final List<NotificationDto> items;

  /// 이 화면을 연 뒤 **실시간으로 도착한** 알림의 id. 화면이 이걸로 새 항목을 구분한다.
  final Set<int> justArrivedIds;

  final StompConnectionState connection;

  /// 지금 보고 있는 학원. 화면 표시용이다.
  final int? tenantId;

  /// 세션에서 유도한 값이 아니라 **고정값**을 쓰고 있는가.
  /// `PLATFORM_ADMIN` 은 소속 학원이 없어 임시로 한 곳을 고정한다(계획서 §8 D3).
  final bool isTenantPinned;

  /// 실시간 스트림에서 난 오류. 이미 받은 목록은 유지한 채 배너로만 알린다 —
  /// 실시간이 깨졌다고 이력까지 지우면 사용자가 볼 게 없어진다.
  final Object? liveError;

  bool get isEmpty => items.isEmpty;

  NotificationFeedState copyWith({
    List<NotificationDto>? items,
    Set<int>? justArrivedIds,
    StompConnectionState? connection,
    Object? liveError,
    bool clearLiveError = false,
  }) => NotificationFeedState(
    items: items ?? this.items,
    justArrivedIds: justArrivedIds ?? this.justArrivedIds,
    connection: connection ?? this.connection,
    tenantId: tenantId,
    isTenantPinned: isTenantPinned,
    liveError: clearLiveError ? null : (liveError ?? this.liveError),
  );
}

/// 알림함.
///
/// ⚠️ **WebSocket 은 "연결된 시점 이후의 변화"만 준다**(MVP_API_SPEC §7.5).
/// 그래서 순서가 중요하다:
///  1. 세션에서 구독 범위(학원 topic / 개인 queue)를 정한다
///  2. **REST 로 과거 이력을 먼저 채운다**
///  3. 그 다음 WebSocket 을 붙여 도착분만 앞에 덧붙인다
///  4. 화면을 벗어나면 구독과 연결을 모두 정리한다(누수 방지)
///
/// 2와 3 사이에 도착한 알림은 REST 이력에도, WS 에도 나타날 수 있다 —
/// 그래서 [_onArrived] 가 `id` 로 중복을 걸러낸다.
class NotificationFeedController extends AsyncNotifier<NotificationFeedState> {
  /// `PLATFORM_ADMIN` 이 볼 학원. 토큰에 소속이 없어 고를 방법이 없으므로 시드 기준
  /// 한 곳으로 고정한다(계획서 §8 D3). 학원 선택 UI 가 생기면 이 상수는 사라진다.
  static const platformAdminPinnedTenantId = 1;

  StompConnectionState _connection = const StompConnectionState(
    StompConnectionStatus.disconnected,
  );

  @override
  Future<NotificationFeedState> build() async {
    final session = ref.watch(currentSessionProvider);
    if (session == null) return const NotificationFeedState();

    final scope = _FeedScope.of(session);
    final repository = ref.read(notificationRepositoryProvider);
    final gateway = ref.read(stompGatewayProvider);

    // (2) 이력 먼저. 실패하면 화면 전체가 에러다 — 보여줄 게 아무것도 없기 때문이다.
    final history = scope.canReadHistory
        ? await repository.getTenantHistory(tenantId: scope.queryTenantId)
        : const <NotificationDto>[];

    _connection = gateway.state;
    final connectionSub = gateway.states.listen(_onConnectionChanged);

    // (3) 실시간. 기사는 개인 큐, 관리자는 학원 topic 이다.
    final feed = switch (scope.topicTenantId) {
      final int tenantId => repository.watchTenant(tenantId),
      null when scope.usesPersonalQueue => repository.watchMine(),
      _ => null,
    };
    final feedSub = feed?.listen(_onArrived, onError: _onLiveError);

    // (4) 화면을 벗어나면(=provider 폐기) 구독과 소켓을 모두 정리한다.
    ref.onDispose(() {
      connectionSub.cancel();
      feedSub?.cancel();
      gateway.disconnect();
    });

    if (feed != null) unawaited(gateway.connect());

    return NotificationFeedState(
      items: history,
      connection: _connection,
      tenantId: scope.displayTenantId,
      isTenantPinned: scope.isPinned,
    );
  }

  /// 이력 다시 불러오기. provider 를 통째로 다시 만들어 **구독도 함께 재생성**한다 —
  /// build 를 직접 부르면 이전 구독이 살아남아 메시지가 두 번씩 들어온다.
  void refresh() => ref.invalidateSelf();

  /// 새 항목 강조를 지운다(사용자가 확인함).
  void clearHighlights() {
    final current = state.value;
    if (current == null || current.justArrivedIds.isEmpty) return;
    state = AsyncValue.data(current.copyWith(justArrivedIds: const {}));
  }

  /// 실시간으로 도착한 알림 한 건.
  void _onArrived(NotificationDto arrived) {
    final current = state.value;
    if (current == null) return;
    // REST 이력을 읽는 사이에 도착한 건이 양쪽에 다 있을 수 있다.
    if (current.items.any((e) => e.id == arrived.id)) return;

    state = AsyncValue.data(
      current.copyWith(
        items: [arrived, ...current.items],
        justArrivedIds: {...current.justArrivedIds, arrived.id},
        clearLiveError: true,
      ),
    );
  }

  void _onLiveError(Object error) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(liveError: error));
  }

  void _onConnectionChanged(StompConnectionState connection) {
    _connection = connection;
    final current = state.value;
    if (current == null) return; // 아직 이력 로딩 중 — build 가 최신값을 싣는다.
    state = AsyncValue.data(current.copyWith(connection: connection));
  }
}

/// 역할에 따라 달라지는 것들을 한 곳에 모은 것.
///
/// 역할 분기를 화면·컨트롤러 곳곳에 흩어놓으면 "관리자만 되는 구독"을 기사가 시도해
/// **연결 자체가 끊기는** 사고가 난다(§7.3 인가 검사).
class _FeedScope {
  const _FeedScope({
    this.topicTenantId,
    this.queryTenantId,
    this.displayTenantId,
    this.canReadHistory = false,
    this.usesPersonalQueue = false,
    this.isPinned = false,
  });

  /// 구독할 학원 topic. null 이면 학원 broadcast 를 구독하지 않는다.
  final int? topicTenantId;

  /// `GET /api/notifications` 에 실을 값. `ACADEMY_ADMIN` 은 **생략**해야 한다.
  final int? queryTenantId;

  /// 화면에 보여줄 학원 번호.
  final int? displayTenantId;

  final bool canReadHistory;
  final bool usesPersonalQueue;
  final bool isPinned;

  static _FeedScope of(AuthSession session) => switch (session.role) {
    // 소속이 없어 고를 수가 없다 → 고정값. REST 에는 반드시 실어야 한다(생략 시 400).
    Role.platformAdmin => const _FeedScope(
      topicTenantId: NotificationFeedController.platformAdminPinnedTenantId,
      queryTenantId: NotificationFeedController.platformAdminPinnedTenantId,
      displayTenantId: NotificationFeedController.platformAdminPinnedTenantId,
      canReadHistory: true,
      isPinned: true,
    ),
    // 서버가 본인 학원으로 처리하므로 쿼리에는 넣지 않는다. topic 은 번호가 필요하다.
    Role.academyAdmin => _FeedScope(
      topicTenantId: session.tenantId,
      displayTenantId: session.tenantId,
      canReadHistory: true,
    ),
    // 학원 topic 은 관리자 전용이다 — 기사가 구독하면 거부되고 세션까지 닫힌다.
    Role.driver => const _FeedScope(usesPersonalQueue: true),
    // 학생·학부모 화면은 MVP 범위 밖이다(계획서 §0). 개인 큐만 열어 둔다.
    Role.student || Role.parent => const _FeedScope(usesPersonalQueue: true),
  };
}

/// 화면을 벗어나면 소켓이 닫히도록 **autoDispose** 다.
final notificationFeedControllerProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationFeedController,
      NotificationFeedState
    >(NotificationFeedController.new);
