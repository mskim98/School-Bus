import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/routing/application/driver_route_controller.dart';
import 'package:school_bus/features/routing/domain/route_plan.dart';
import 'package:school_bus/features/routing/domain/route_plan_status.dart';

void main() {
  RoutePlan plan(
    int id,
    RouteDirection direction, {
    int version = 1,
    double distance = 1000,
  }) => RoutePlan(
    id: id,
    busId: 1,
    direction: direction,
    serviceDate: DateTime(2026, 7, 29),
    totalDistanceM: distance,
    totalDuration: const Duration(seconds: 400),
    path: const [],
    stops: const [],
    status: RoutePlanStatus.published,
    version: version,
  );

  group('DriverRouteState.current — 어떤 노선을 보여줄 것인가', () {
    test('노선이 없으면 null', () {
      expect(const DriverRouteState().current, isNull);
    });

    test('고른 방향이 없으면 서버가 먼저 준 방향', () {
      final state = DriverRouteState(
        plans: [plan(1, RouteDirection.dropoff), plan(2, RouteDirection.pickup)],
      );

      expect(state.current?.direction, RouteDirection.dropoff);
    });

    test('고른 방향의 노선을 보여준다', () {
      final state = DriverRouteState(
        plans: [plan(1, RouteDirection.dropoff), plan(2, RouteDirection.pickup)],
        selected: RouteDirection.pickup,
      );

      expect(state.current?.id, 2);
    });

    // ★ 서버는 방향으로만 정렬해 주고(OrderByDirectionAsc) 버전은 안 본다.
    //   재배차하면 같은 방향에 version 이 다른 행이 쌓이는데, 첫 줄을 그대로
    //   쓰면 기사가 **재배차 전의 옛 노선**으로 운행하게 된다.
    test('★ 같은 방향이 여러 회차면 최신 version 을 고른다', () {
      final state = DriverRouteState(
        plans: [
          // 서버가 옛 회차를 먼저 줄 수 있다 — 순서를 믿지 않는다.
          plan(1, RouteDirection.pickup, version: 1, distance: 1566),
          plan(2, RouteDirection.pickup, version: 3, distance: 2100),
          plan(3, RouteDirection.pickup, version: 2, distance: 1800),
        ],
        selected: RouteDirection.pickup,
      );

      expect(state.current?.id, 2);
      expect(state.current?.version, 3);
    });

    test('★ 방향을 고르지 않았을 때도 최신 version 을 고른다', () {
      final state = DriverRouteState(
        plans: [
          plan(1, RouteDirection.pickup, version: 1),
          plan(2, RouteDirection.pickup, version: 2),
        ],
      );

      expect(state.current?.version, 2);
    });

    test('고른 방향의 노선이 하나도 없으면 첫 노선으로 물러난다', () {
      final state = DriverRouteState(
        plans: [plan(1, RouteDirection.pickup)],
        selected: RouteDirection.dropoff,
      );

      expect(state.current?.id, 1, reason: '빈 화면보다 낫다');
    });

    test('방향 탭은 중복 없이 나온다', () {
      final state = DriverRouteState(
        plans: [
          plan(1, RouteDirection.pickup, version: 1),
          plan(2, RouteDirection.pickup, version: 2),
          plan(3, RouteDirection.dropoff),
        ],
      );

      expect(state.availableDirections, hasLength(2));
    });
  });
}
