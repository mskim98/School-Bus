import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/location/impl/location_source_factory_impl.dart';
import '../../../core/location/spec/location_source.dart';
import '../../../core/location/spec/location_source_kind.dart';
import '../../../core/map/spec/map_view_adapter.dart';
import '../../auth/application/auth_controller.dart';
import '../data/location_repository.dart';

/// 기사 위치 보고 상태.
///
/// `AsyncValue` 대신 평범한 상태 객체를 쓴다 — 5초마다 도는 백그라운드 작업이라
/// 매 tick 마다 화면을 loading 으로 되돌리면 표시가 계속 깜빡인다.
class DriverLocationState {
  const DriverLocationState({
    this.enabled = false,
    this.pausedByLifecycle = false,
    this.sourceKind = LocationSourceKind.mock,
    this.lastPoint,
    this.lastSentAt,
    this.sentCount = 0,
    this.errorMessage,
  });

  /// 기사가 전송 스위치를 켰는가.
  final bool enabled;

  /// 앱이 백그라운드로 가서 타이머를 잠시 멈춘 상태.
  /// [enabled] 는 그대로 두고 돌아왔을 때 자동으로 재개한다.
  final bool pausedByLifecycle;

  final LocationSourceKind sourceKind;

  final GeoPoint? lastPoint;
  final DateTime? lastSentAt;

  /// 켠 뒤 성공적으로 보낸 횟수. "정말 가고 있는가"를 눈으로 확인하는 값이다.
  final int sentCount;

  /// 마지막 실패 사유. 서버·포트가 준 문구를 **그대로** 보여준다(컨벤션 §7-2).
  final String? errorMessage;

  /// 지금 실제로 좌표가 나가고 있는가.
  bool get isReporting => enabled && !pausedByLifecycle;

  DriverLocationState copyWith({
    bool? enabled,
    bool? pausedByLifecycle,
    LocationSourceKind? sourceKind,
    GeoPoint? lastPoint,
    DateTime? lastSentAt,
    int? sentCount,
    String? errorMessage,
    bool clearError = false,
  }) => DriverLocationState(
    enabled: enabled ?? this.enabled,
    pausedByLifecycle: pausedByLifecycle ?? this.pausedByLifecycle,
    sourceKind: sourceKind ?? this.sourceKind,
    lastPoint: lastPoint ?? this.lastPoint,
    lastSentAt: lastSentAt ?? this.lastSentAt,
    sentCount: sentCount ?? this.sentCount,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// 기사 단말의 좌표를 [reportInterval] 마다 서버로 보낸다(C8).
///
/// 흐름: 타이머 → [LocationSource.read] → `POST /api/locations/bus` → 상태 갱신.
/// 좌표를 어디서 얻는지는 [LocationSourceFactory] 뒤에 숨겨 두었으므로 이 클래스는
/// `geolocator` 를 모른다(컨벤션 §3, 검사 C-1).
class DriverLocationController extends Notifier<DriverLocationState> {
  /// 전송 주기. 서버 위치 갱신·관제 폴링(각 3초)과 균형을 맞춘 값이다(계획서 §8 D2).
  static const reportInterval = Duration(seconds: 5);

  Timer? _timer;
  LocationSource? _source;

  @override
  DriverLocationState build() {
    // 화면을 벗어나 provider 가 정리될 때 타이머가 살아남지 않게 한다.
    ref.onDispose(_cancelTimer);
    return const DriverLocationState();
  }

  /// 전송 스위치. [mockPath] 는 Mock 이 따라갈 노선 좌표다(화면이 이미 조회한 값).
  Future<void> setEnabled(
    bool value, {
    required List<GeoPoint> mockPath,
  }) async {
    if (value == state.enabled) return;

    if (!value) {
      _cancelTimer();
      _source = null;
      state = state.copyWith(
        enabled: false,
        pausedByLifecycle: false,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      enabled: true,
      pausedByLifecycle: false,
      sentCount: 0,
      clearError: true,
    );
    _source = _createSource(state.sourceKind, mockPath);
    _startTimer();
  }

  /// Mock ↔ 실 GPS 전환. 전송 중이면 새 출처로 즉시 이어서 보낸다.
  void setSourceKind(
    LocationSourceKind kind, {
    required List<GeoPoint> mockPath,
  }) {
    if (kind == state.sourceKind) return;
    state = state.copyWith(sourceKind: kind, clearError: true);
    if (!state.isReporting) return;

    _source = _createSource(kind, mockPath);
    _startTimer();
  }

  /// 앱이 백그라운드로 갔다 — 타이머를 정리한다(누수·불필요한 전송 방지).
  void pause() {
    if (!state.enabled || state.pausedByLifecycle) return;
    _cancelTimer();
    state = state.copyWith(pausedByLifecycle: true);
  }

  /// 앱이 다시 앞으로 나왔다 — 켜져 있던 전송을 재개한다.
  void resume({required List<GeoPoint> mockPath}) {
    if (!state.enabled || !state.pausedByLifecycle) return;
    state = state.copyWith(pausedByLifecycle: false);
    _source ??= _createSource(state.sourceKind, mockPath);
    _startTimer();
  }

  LocationSource _createSource(LocationSourceKind kind, List<GeoPoint> path) {
    return ref.read(locationSourceFactoryProvider).create(kind, mockPath: path);
  }

  void _startTimer() {
    _cancelTimer();
    _timer = Timer.periodic(reportInterval, (_) => _tick());
    // 켜자마자 한 번 보낸다 — 5초를 기다리게 하면 켜졌는지 확신할 수 없다.
    unawaited(_tick());
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    final busId = ref.read(currentSessionProvider)?.busId;
    if (busId == null) {
      // 배차 전 기사는 보고할 대상이 없다. 계속 시도해봐야 400 만 쌓인다.
      _stopWithError('배차된 버스가 없어 위치를 보고할 수 없습니다. 관리자에게 배차를 요청해 주세요');
      return;
    }

    final source = _source;
    if (source == null) return;

    try {
      final point = await source.read();
      await ref
          .read(locationRepositoryProvider)
          .reportBusLocation(busId: busId, lat: point.lat, lng: point.lng);

      // await 사이에 화면을 벗어났을 수 있다 — 정리된 뒤 state 를 쓰면 예외가 난다.
      if (!ref.mounted) return;
      state = state.copyWith(
        lastPoint: point,
        lastSentAt: DateTime.now(),
        sentCount: state.sentCount + 1,
        clearError: true,
      );
    } on LocationUnavailableException catch (e) {
      // 권한 거부·노선 없음 — 사용자가 무언가 바꾸기 전엔 재시도해도 같다.
      if (!ref.mounted) return;
      _stopWithError(e.message);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      _handleApiFailure(e);
    }
  }

  /// 실패 갈래를 **HTTP status(kind)로만** 나눈다(컨벤션 §7-1).
  ///
  /// 401 은 인터셉터가 재발급을 시도하고도 실패한 경우라 다시 보내봐야 소용없다.
  /// 반대로 네트워크·5xx 는 일시적일 수 있으니 다음 주기에 그대로 재시도한다.
  void _handleApiFailure(ApiException e) {
    final permanent = switch (e.kind) {
      ApiErrorKind.unauthorized ||
      ApiErrorKind.forbidden ||
      ApiErrorKind.badRequest ||
      ApiErrorKind.notFound => true,
      ApiErrorKind.network ||
      ApiErrorKind.server ||
      ApiErrorKind.conflict ||
      ApiErrorKind.unknown => false,
    };

    if (permanent) {
      _stopWithError(e.message);
    } else {
      state = state.copyWith(errorMessage: e.message);
    }
  }

  void _stopWithError(String message) {
    _cancelTimer();
    _source = null;
    state = state.copyWith(
      enabled: false,
      pausedByLifecycle: false,
      errorMessage: message,
    );
  }
}

final driverLocationControllerProvider =
    NotifierProvider<DriverLocationController, DriverLocationState>(
      DriverLocationController.new,
    );
