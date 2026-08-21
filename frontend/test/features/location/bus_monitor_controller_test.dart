import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/auth/application/auth_controller.dart';
import 'package:school_bus/features/location/application/bus_monitor_controller.dart';
import 'package:school_bus/features/location/data/dto/bus_location_dto.dart';
import 'package:school_bus/features/location/data/dto/bus_summary_dto.dart';
import 'package:school_bus/features/location/data/location_repository.dart';
import 'package:school_bus/features/location/domain/monitored_bus.dart';
import 'package:school_bus/shared/domain/auth_session.dart';
import 'package:school_bus/shared/domain/role.dart';

class _FakeRepository implements LocationRepository {
  _FakeRepository({this.buses = const [], this.locations = const []});

  final List<BusSummaryDto> buses;
  final List<BusLocationDto> locations;

  /// 각 호출에 실린 tenantId — 생략/고정값 규칙 검증에 쓴다.
  final tenantIds = <int?>[];

  @override
  Future<void> reportBusLocation({
    required int busId,
    required double lat,
    required double lng,
    required LocationOrigin origin,
  }) async {}

  @override
  Future<List<BusLocationDto>> getBusLocations({int? tenantId}) async {
    tenantIds.add(tenantId);
    return locations;
  }

  @override
  Future<List<BusSummaryDto>> getBuses({int? tenantId}) async {
    tenantIds.add(tenantId);
    return buses;
  }
}

AuthSession _admin(Role role, {int? tenantId}) => AuthSession(
  userId: 1,
  email: 'admin@school.com',
  role: role,
  tenantId: tenantId,
);

const _buses = [
  BusSummaryDto(id: 1, name: '3호차', driverName: '박기사'),
  BusSummaryDto(id: 2, name: '1호차'),
];

const _locations = [
  BusLocationDto(
    busId: 1,
    busName: '3호차',
    lat: 37.5075,
    lng: 127.0355,
    recordedAt: '2026-07-28T12:34:26.199274169',
    origin: 'MOCK',
  ),
];

void main() {
  late _FakeRepository repository;

  ProviderContainer containerWith(AuthSession session) {
    repository = _FakeRepository(buses: _buses, locations: _locations);
    final container = ProviderContainer(
      overrides: [
        currentSessionProvider.overrideWithValue(session),
        locationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    // dispose 가 폴링 타이머까지 정리한다 — 안 하면 테스트가 끝나도 3초마다 돈다.
    addTearDown(container.dispose);
    return container;
  }

  group('tenantId 결정 (계획서 §8 D3)', () {
    test('학원 관리자는 세션의 소속 학원을 쓴다', () async {
      final container = containerWith(_admin(Role.academyAdmin, tenantId: 1));

      final state = await container.read(busMonitorControllerProvider.future);

      expect(state.tenantId, 1);
      expect(state.isTenantFallback, isFalse);
      expect(repository.tenantIds, everyElement(1));
    });

    test('★ 플랫폼 관리자는 소속이 없다 → 고정값을 쓰고 화면에 표시한다', () async {
      // tenantId 를 빼면 서버가 400 을 준다(실측). 그래서 생략이 아니라 고정값이다.
      final container = containerWith(
        _admin(Role.platformAdmin, tenantId: null),
      );

      final state = await container.read(busMonitorControllerProvider.future);

      expect(state.tenantId, platformAdminFallbackTenantId);
      expect(state.isTenantFallback, isTrue, reason: '화면이 "고정값"임을 알려야 한다');
    });
  });

  group('초기 로드', () {
    test('★ 위치가 없는 버스도 목록에 세운다 — 위치 응답에서 빠질 뿐이다', () async {
      final container = containerWith(_admin(Role.academyAdmin, tenantId: 1));

      final state = await container.read(busMonitorControllerProvider.future);

      expect(state.buses, hasLength(2));
      expect(state.positionedCount, 1);
      expect(state.buses.last.hasPosition, isFalse);
      expect(state.pollErrorMessage, isNull);
      expect(state.updatedAt, isNotNull);
    });

    test('버스 명단을 상태에 들고 있는다 — 폴링은 위치만 다시 부르기 때문', () async {
      final container = containerWith(_admin(Role.academyAdmin, tenantId: 1));

      final state = await container.read(busMonitorControllerProvider.future);

      expect(state.roster, hasLength(2));
    });
  });

  group('선택', () {
    test('버스를 고르고, 같은 버스를 다시 누르면 해제된다', () async {
      final container = containerWith(_admin(Role.academyAdmin, tenantId: 1));
      await container.read(busMonitorControllerProvider.future);
      final controller = container.read(busMonitorControllerProvider.notifier);

      controller.select(1);
      expect(
        container.read(busMonitorControllerProvider).value!.selectedBusId,
        1,
      );
      expect(
        container.read(busMonitorControllerProvider).value!.selectedBus?.name,
        '3호차',
      );

      controller.select(1);
      expect(
        container.read(busMonitorControllerProvider).value!.selectedBusId,
        isNull,
      );
    });

    test('null 을 주면 선택이 풀린다 — "전체 보기"', () async {
      final container = containerWith(_admin(Role.academyAdmin, tenantId: 1));
      await container.read(busMonitorControllerProvider.future);
      final controller = container.read(busMonitorControllerProvider.notifier);

      controller.select(2);
      controller.select(null);

      expect(
        container.read(busMonitorControllerProvider).value!.selectedBusId,
        isNull,
      );
    });
  });

  group('라이프사이클', () {
    test('★ 백그라운드로 가면 폴링을 멈추고, 돌아오면 재개한다', () async {
      final container = containerWith(_admin(Role.academyAdmin, tenantId: 1));
      await container.read(busMonitorControllerProvider.future);
      final controller = container.read(busMonitorControllerProvider.notifier);

      controller.pause();
      expect(
        container.read(busMonitorControllerProvider).value!.pausedByLifecycle,
        isTrue,
      );

      controller.resume();
      expect(
        container.read(busMonitorControllerProvider).value!.pausedByLifecycle,
        isFalse,
      );
    });
  });
}
