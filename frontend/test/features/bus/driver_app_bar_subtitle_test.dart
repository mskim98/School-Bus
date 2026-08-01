import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/bus/application/my_bus_controller.dart';
import 'package:school_bus/features/bus/data/dto/my_bus_dto.dart';
import 'package:school_bus/features/bus/domain/my_bus.dart';
import 'package:school_bus/features/bus/presentation/widget/driver_app_bar_subtitle.dart';
import 'package:school_bus/features/drivesession/application/drive_session_controller.dart';
import 'package:school_bus/features/drivesession/domain/drive_session.dart';

/// 서버를 타지 않고 정해진 버스만 돌려준다.
class _FakeMyBusController extends MyBusController {
  _FakeMyBusController(this.bus);

  final MyBus? bus;

  @override
  Future<MyBus?> build() async => bus;
}

MyBus busOf({String? name = '3호차', String? routeName = '하원 A노선'}) =>
    MyBus.fromDto(
      MyBusDto(
        id: 3,
        seatCapacity: 25,
        onboard: 3,
        name: name,
        routeName: routeName,
      ),
    );

DriveSession sessionOf() => DriveSession(
  id: 1,
  busId: 3,
  direction: DriveDirection.dropoff,
  serviceDate: DateTime(2026, 7, 28),
  isInProgress: true,
  startedAt: DateTime(2026, 7, 28, 14),
);

Future<void> pumpSubtitle(
  WidgetTester tester, {
  MyBus? bus,
  DriveSession? session,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        myBusControllerProvider.overrideWith(() => _FakeMyBusController(bus)),
        activeDriveSessionProvider.overrideWithValue(session),
      ],
      child: const MaterialApp(home: Scaffold(body: DriverAppBarSubtitle())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('★ 버스를 아직 못 받았으면 아무것도 그리지 않는다', (tester) async {
    // 자리표시자를 두면 앱바가 두 줄로 커졌다 줄었다 하며 제목이 흔들린다.
    await pumpSubtitle(tester, bus: null);

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('운행 전에는 날짜 없이 호차 · 노선까지만', (tester) async {
    await pumpSubtitle(tester, bus: busOf(), session: null);

    expect(find.text('3호차 · 하원 A노선'), findsOneWidget);
  });

  testWidgets('★ 운행 중이면 세션의 serviceDate 를 붙인다 — 기기 시계가 아니다', (tester) async {
    await pumpSubtitle(tester, bus: busOf(), session: sessionOf());

    expect(find.text('3호차 · 하원 A노선 · 2026. 7. 28.'), findsOneWidget);
  });

  testWidgets('노선이 없으면 그 조각만 빠진다', (tester) async {
    await pumpSubtitle(tester, bus: busOf(routeName: null), session: null);

    expect(find.text('3호차'), findsOneWidget);
  });
}
