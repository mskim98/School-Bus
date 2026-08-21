import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/api/api_exception.dart';
import 'package:school_bus/core/location/spec/location_source.dart';
import 'package:school_bus/core/location/spec/location_source_factory.dart';
import 'package:school_bus/core/location/spec/location_source_kind.dart';
import 'package:school_bus/core/map/spec/map_view_adapter.dart';
import 'package:school_bus/features/auth/application/auth_controller.dart';
import 'package:school_bus/features/location/application/driver_location_controller.dart';
import 'package:school_bus/features/location/data/dto/bus_location_dto.dart';
import 'package:school_bus/features/location/data/dto/bus_summary_dto.dart';
import 'package:school_bus/features/location/data/location_repository.dart';
import 'package:school_bus/features/location/domain/monitored_bus.dart';
import 'package:school_bus/shared/domain/auth_session.dart';
import 'package:school_bus/shared/domain/role.dart';

/// 좌표를 정해진 값으로 주거나, 지정한 예외를 던진다.
class _FakeSource implements LocationSource {
  _FakeSource({this.error});

  static const point = GeoPoint(37.5, 127.0);

  final Object? error;
  int readCount = 0;

  @override
  Future<GeoPoint> read() async {
    readCount++;
    if (error != null) throw error!;
    return point;
  }
}

class _FakeFactory implements LocationSourceFactory {
  _FakeFactory(this.source);

  final _FakeSource source;
  LocationSourceKind? lastKind;
  List<GeoPoint>? lastPath;

  @override
  LocationSource create(
    LocationSourceKind kind, {
    required List<GeoPoint> mockPath,
  }) {
    lastKind = kind;
    lastPath = mockPath;
    return source;
  }
}

/// 보고 요청을 기록하거나 지정한 [ApiException] 을 던진다.
class _FakeRepository implements LocationRepository {
  _FakeRepository({this.error});

  final ApiException? error;
  final reports = <({int busId, double lat, double lng, LocationOrigin origin})>[
  ];

  @override
  Future<void> reportBusLocation({
    required int busId,
    required double lat,
    required double lng,
    required LocationOrigin origin,
  }) async {
    reports.add((busId: busId, lat: lat, lng: lng, origin: origin));
    if (error != null) throw error!;
  }

  @override
  Future<List<BusLocationDto>> getBusLocations({int? tenantId}) async =>
      const [];

  @override
  Future<List<BusSummaryDto>> getBuses({int? tenantId}) async => const [];
}

AuthSession _driver({int? busId = 1}) => AuthSession(
  userId: 3,
  email: 'driver@school.com',
  role: Role.driver,
  tenantId: 1,
  busId: busId,
);

/// `setEnabled` 는 첫 전송을 기다리지 않고 돌아온다(즉시 1회 + 이후 타이머).
/// 그 첫 전송이 끝나도록 이벤트 루프를 몇 바퀴 돌린다.
Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeSource source;
  late _FakeFactory factory;
  late _FakeRepository repository;

  ProviderContainer containerWith({
    AuthSession? session,
    ApiException? apiError,
    Object? sourceError,
  }) {
    source = _FakeSource(error: sourceError);
    factory = _FakeFactory(source);
    repository = _FakeRepository(error: apiError);

    final container = ProviderContainer(
      overrides: [
        currentSessionProvider.overrideWithValue(session),
        locationSourceFactoryProvider.overrideWithValue(factory),
        locationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('기본 상태', () {
    test('꺼져 있고 출처는 Mock 이다 — 위치 권한 없이 시연할 수 있어야 한다', () {
      final container = containerWith(session: _driver());

      final state = container.read(driverLocationControllerProvider);

      expect(state.enabled, isFalse);
      expect(state.isReporting, isFalse);
      expect(state.sourceKind, LocationSourceKind.mock);
    });
  });

  group('전송 켜기', () {
    test('★ 켜자마자 1회 보낸다 — busId 는 세션에서 온다(하드코딩 금지)', () async {
      final container = containerWith(session: _driver(busId: 7));
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      await controller.setEnabled(
        true,
        mockPath: const [GeoPoint(37.5, 127.0)],
      );
      await _settle();

      expect(repository.reports, hasLength(1));
      expect(repository.reports.single.busId, 7);
      expect(repository.reports.single.lat, 37.5);

      final state = container.read(driverLocationControllerProvider);
      expect(state.isReporting, isTrue);
      expect(state.sentCount, 1);
      expect(state.errorMessage, isNull);

      await controller.setEnabled(false, mockPath: const []);
    });

    test('노선 좌표를 Mock 출처에 그대로 넘긴다', () async {
      final container = containerWith(session: _driver());
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );
      const path = [GeoPoint(37.501, 127.0275), GeoPoint(37.5075, 127.0355)];

      await controller.setEnabled(true, mockPath: path);
      await _settle();

      expect(factory.lastKind, LocationSourceKind.mock);
      expect(factory.lastPath, path);

      await controller.setEnabled(false, mockPath: const []);
    });

    test('★ 담당 버스가 없으면 아예 보내지 않고 이유를 남긴다', () async {
      final container = containerWith(session: _driver(busId: null));
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      await controller.setEnabled(
        true,
        mockPath: const [GeoPoint(37.5, 127.0)],
      );
      await _settle();

      expect(repository.reports, isEmpty);
      final state = container.read(driverLocationControllerProvider);
      expect(state.enabled, isFalse, reason: '재시도해도 같으므로 멈춘다');
      expect(state.errorMessage, contains('배차'));
    });
  });

  group('출처 전환', () {
    test('전송 중에 실 GPS 로 바꾸면 새 출처로 다시 만든다', () async {
      final container = containerWith(session: _driver());
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      await controller.setEnabled(
        true,
        mockPath: const [GeoPoint(37.5, 127.0)],
      );
      await _settle();
      controller.setSourceKind(LocationSourceKind.gps, mockPath: const []);
      await _settle();

      expect(factory.lastKind, LocationSourceKind.gps);
      expect(
        container.read(driverLocationControllerProvider).sourceKind,
        LocationSourceKind.gps,
      );

      await controller.setEnabled(false, mockPath: const []);
    });

    test('★ Mock 으로 보내는 좌표는 보고에 MOCK 으로 표시된다', () async {
      final container = containerWith(session: _driver());
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      await controller.setEnabled(
        true,
        mockPath: const [GeoPoint(37.5, 127.0)],
      );
      await _settle();

      expect(repository.reports.single.origin, LocationOrigin.mock);
      expect(LocationOrigin.mock.wireName, 'MOCK');

      await controller.setEnabled(false, mockPath: const []);
    });

    test('★ 실 GPS 로 켜면 보고에 GPS 로 나간다', () async {
      final container = containerWith(session: _driver());
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      controller.setSourceKind(LocationSourceKind.gps, mockPath: const []);
      await controller.setEnabled(true, mockPath: const []);
      await _settle();

      expect(repository.reports.single.origin, LocationOrigin.gps);
      expect(LocationOrigin.gps.wireName, 'GPS');

      await controller.setEnabled(false, mockPath: const []);
    });

    test('★ 전환 직후 보고부터 새 출처가 실린다 — 옛 출처가 계속 나가면 표기가 거짓이 된다', () async {
      final container = containerWith(session: _driver());
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      await controller.setEnabled(
        true,
        mockPath: const [GeoPoint(37.5, 127.0)],
      );
      await _settle();
      final beforeSwitch = repository.reports.length;

      controller.setSourceKind(LocationSourceKind.gps, mockPath: const []);
      await _settle();

      expect(
        repository.reports.length,
        greaterThan(beforeSwitch),
        reason: '전환은 타이머를 다시 걸며 즉시 1회 보낸다',
      );
      expect(
        repository.reports.take(beforeSwitch).map((r) => r.origin),
        everyElement(LocationOrigin.mock),
        reason: '전환 전 보고는 Mock 그대로다',
      );
      expect(
        repository.reports.skip(beforeSwitch).map((r) => r.origin),
        everyElement(LocationOrigin.gps),
      );

      await controller.setEnabled(false, mockPath: const []);
    });

    test('꺼져 있을 때 바꾸면 전송이 시작되지 않는다', () async {
      final container = containerWith(session: _driver());
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      controller.setSourceKind(LocationSourceKind.gps, mockPath: const []);
      await _settle();

      expect(repository.reports, isEmpty);
      expect(container.read(driverLocationControllerProvider).enabled, isFalse);
    });
  });

  group('실패 처리 — 분기는 HTTP status 로만 한다(컨벤션 §7-1)', () {
    test('★ 403 은 다시 보내도 같다 → 전송을 멈추고 서버 문구를 그대로 보여준다', () async {
      final container = containerWith(
        session: _driver(),
        apiError: ApiException.fromStatus(403, '담당 버스가 아닙니다'),
      );
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      await controller.setEnabled(
        true,
        mockPath: const [GeoPoint(37.5, 127.0)],
      );
      await _settle();

      final state = container.read(driverLocationControllerProvider);
      expect(state.enabled, isFalse);
      expect(state.errorMessage, '담당 버스가 아닙니다');
    });

    test('★ 5xx·네트워크는 일시적일 수 있다 → 켜둔 채 사유만 남긴다', () async {
      final container = containerWith(
        session: _driver(),
        apiError: ApiException.network(),
      );
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      await controller.setEnabled(
        true,
        mockPath: const [GeoPoint(37.5, 127.0)],
      );
      await _settle();

      final state = container.read(driverLocationControllerProvider);
      expect(state.enabled, isTrue, reason: '다음 주기에 다시 시도한다');
      expect(state.errorMessage, isNotNull);

      await controller.setEnabled(false, mockPath: const []);
    });

    test('★ 좌표를 못 얻으면(권한 거부·노선 없음) 멈추고 안내한다', () async {
      final container = containerWith(
        session: _driver(),
        sourceError: const LocationUnavailableException('위치 권한이 거부되었습니다'),
      );
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      await controller.setEnabled(true, mockPath: const []);
      await _settle();

      expect(repository.reports, isEmpty);
      final state = container.read(driverLocationControllerProvider);
      expect(state.enabled, isFalse);
      expect(state.errorMessage, '위치 권한이 거부되었습니다');
    });
  });

  group('타이머 정리', () {
    test('★ 끄면 더 이상 보내지 않는다', () async {
      final container = containerWith(session: _driver());
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      await controller.setEnabled(
        true,
        mockPath: const [GeoPoint(37.5, 127.0)],
      );
      await _settle();
      final sentWhileOn = repository.reports.length;

      await controller.setEnabled(false, mockPath: const []);
      await _settle();

      expect(repository.reports, hasLength(sentWhileOn));
      expect(container.read(driverLocationControllerProvider).enabled, isFalse);
    });

    test('★ 화면이 백그라운드로 가면 전송을 멈추고, 돌아오면 재개한다', () async {
      final container = containerWith(session: _driver());
      final controller = container.read(
        driverLocationControllerProvider.notifier,
      );

      await controller.setEnabled(
        true,
        mockPath: const [GeoPoint(37.5, 127.0)],
      );
      await _settle();

      controller.pause();
      var state = container.read(driverLocationControllerProvider);
      expect(state.enabled, isTrue, reason: '사용자가 끈 게 아니다');
      expect(state.isReporting, isFalse);
      expect(state.pausedByLifecycle, isTrue);

      controller.resume(mockPath: const [GeoPoint(37.5, 127.0)]);
      await _settle();
      state = container.read(driverLocationControllerProvider);
      expect(state.isReporting, isTrue);
      expect(state.pausedByLifecycle, isFalse);

      await controller.setEnabled(false, mockPath: const []);
    });
  });
}
