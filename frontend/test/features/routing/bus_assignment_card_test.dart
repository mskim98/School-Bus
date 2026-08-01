import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/app/theme/app_theme.dart';
import 'package:school_bus/core/map/spec/map_view_adapter.dart';
import 'package:school_bus/features/routing/domain/route_plan.dart';
import 'package:school_bus/features/routing/domain/route_plan_status.dart';
import 'package:school_bus/features/routing/presentation/widget/bus_assignment_card.dart';

/// 확정은 되돌릴 수 없는 동작이라, 이 카드가 내는 표기가 곧 **관리자의 판단 근거**다.
/// 여기서 지키는 건 셋이다 — 정차 단위 묶음(§5.4) · 정원 상태를 색만으로
/// 구분하지 않기(§0-1) · 명부가 없어도 화면이 뜨는 것(컨벤션 §9 C-1 예외 조건 ③).
void main() {
  RouteStop stop(int seq, int studentId, double lat, double lng) => RouteStop(
    seq: seq,
    studentId: studentId,
    point: GeoPoint(lat, lng),
    eta: Duration(seconds: seq * 60),
  );

  RoutePlan planOf({
    int id = 1,
    int busId = 3,
    double distanceM = 3500,
    int durationS = 1016,
    List<RouteStop> stops = const [],
  }) => RoutePlan(
    id: id,
    busId: busId,
    direction: RouteDirection.pickup,
    serviceDate: DateTime(2026, 7, 29),
    totalDistanceM: distanceM,
    totalDuration: Duration(seconds: durationS),
    path: const [],
    stops: stops,
    status: RoutePlanStatus.recommended,
  );

  Future<void> pump(WidgetTester tester, Widget child, {double scale = 1}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      );

  group('BusAssignmentCard', () {
    // 검증 보고서 케이스 1 의 버스 3(4석, 학생 4명, 3,500m) 이다.
    final fullBus = planOf(
      stops: [
        stop(1, 7, 37.5010, 127.0275),
        stop(2, 8, 37.5010, 127.0275),
        stop(3, 9, 37.5045, 127.0310),
        stop(4, 10, 37.5060, 127.0330),
      ],
    );

    testWidgets('호차명·정원·거리를 함께 낸다', (tester) async {
      await pump(
        tester,
        BusAssignmentCard(
          plan: fullBus,
          busName: '3호차',
          seatCapacity: 4,
          studentNameOf: (id) => '학생$id',
        ),
      );

      expect(find.text('3호차'), findsOneWidget);
      expect(find.text('4 / 4석'), findsOneWidget);
      // 정차 3곳이다 — 같은 좌표 2명을 두 곳으로 세면 안 된다(§5.4).
      expect(find.text('정차 3곳 · 3.5km · 약 17분'), findsOneWidget);
      expect(find.text('배정 학생 4명'), findsOneWidget);
    });

    testWidgets('★ 정원이 가득 찼음을 색만으로 알리지 않는다 — 라벨을 같이 낸다', (tester) async {
      await pump(
        tester,
        BusAssignmentCard(plan: fullBus, busName: '3호차', seatCapacity: 4),
      );

      // §0-1. 진행바 색이 바뀌는 것만으로는 직사광선·색각 이상에서 안 읽힌다.
      expect(find.textContaining('정원 가득'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('자리가 남으면 몇 석 남았는지 숫자로 낸다', (tester) async {
      await pump(
        tester,
        BusAssignmentCard(plan: fullBus, busName: '3호차', seatCapacity: 6),
      );

      expect(find.text('4 / 6석'), findsOneWidget);
      expect(find.textContaining('여유 2석'), findsOneWidget);
    });

    testWidgets('★ 좌석 수를 모르면 정원 칸을 비운다 — 0 으로 채우지 않는다', (tester) async {
      // 0 을 넣으면 진행바가 꽉 차 "정원 초과"로 읽힌다.
      await pump(tester, BusAssignmentCard(plan: fullBus, busName: '3호차'));

      expect(find.text('배정 4명'), findsOneWidget);
      expect(find.text('정원 정보 없음'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('★ 명부가 없어도 카드는 뜬다 — 버스 #id · #studentId 로 남는다', (tester) async {
      // 명부(학생·버스 목록)가 아직 안 왔거나 실패해도 제안 결과가 가려지면
      // 관리자가 확정 판단을 아예 못 한다(컨벤션 §9 C-1 예외 조건 ③).
      await pump(tester, BusAssignmentCard(plan: fullBus));

      expect(find.text('버스 #3'), findsOneWidget);
      expect(find.text('#7, #8'), findsOneWidget, reason: '이름을 지어내지 않는다');
    });

    testWidgets('★ 학생 이름을 정차 단위로 묶어 낸다', (tester) async {
      await pump(
        tester,
        BusAssignmentCard(
          plan: fullBus,
          seatCapacity: 4,
          studentNameOf: (id) =>
              const {7: '김민준', 8: '이서연', 9: '박도윤', 10: '최지우'}[id]!,
        ),
      );

      // 같은 좌표 두 명은 한 줄에 묶인다. 서버 `stops[]` 를 그대로 나열하면
      // 같은 정류장이 인원수만큼 반복된다(§5.4).
      expect(find.text('1번 정차'), findsOneWidget);
      expect(find.text('김민준, 이서연'), findsOneWidget);
      expect(find.text('2번 정차'), findsOneWidget);
      expect(find.text('박도윤'), findsOneWidget);
    });

    testWidgets('인원이 많으면 접고 시작하고, 눌러서 펼친다', (tester) async {
      // 정원은 25석까지 간다(§9) — 전부 펼치면 카드 하나가 화면을 다 먹는다.
      final crowded = planOf(
        stops: [
          for (var i = 0; i < BusAssignmentCard.collapseAbove + 1; i++)
            stop(i + 1, i + 1, 37.50 + i * 0.001, 127.02),
        ],
      );

      await pump(
        tester,
        BusAssignmentCard(plan: crowded, studentNameOf: (id) => '학생$id'),
      );
      expect(find.text('학생1'), findsNothing);

      await tester.tap(find.text('배정 학생 9명'));
      await tester.pumpAndSettle();
      expect(find.text('학생1'), findsOneWidget);
    });

    testWidgets('명단 접기 줄은 48dp 이상 타깃이다', (tester) async {
      await pump(tester, BusAssignmentCard(plan: fullBus));

      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('배정된 학생이 없으면 그 사실을 문장으로 말한다', (tester) async {
      await pump(tester, BusAssignmentCard(plan: planOf(), seatCapacity: 4));

      expect(find.text('이 버스에 배정된 학생이 없습니다.'), findsOneWidget);
      expect(find.text('0 / 4석'), findsOneWidget);
    });

    testWidgets('글자 200% 확대에서도 깨지지 않는다', (tester) async {
      await pump(
        tester,
        BusAssignmentCard(
          plan: fullBus,
          busName: '3호차',
          seatCapacity: 4,
          studentNameOf: (id) => '학생$id',
        ),
        scale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('3호차'), findsOneWidget);
    });
  });

  group('BusDistanceComparison — 버스 간 운행거리', () {
    // 검증 보고서 케이스 1 실측: 4석 3,500m / 6석 7,529m / 3석 3,815m.
    final measured = [
      planOf(id: 1, busId: 3, distanceM: 3500),
      planOf(id: 2, busId: 8, distanceM: 7529),
      planOf(id: 3, busId: 9, distanceM: 3815),
    ];

    testWidgets('버스가 한 대면 그리지 않는다 — 막대 하나는 비교가 아니다', (tester) async {
      await pump(tester, BusDistanceComparison(plans: [measured.first]));

      expect(find.text('버스별 운행거리'), findsNothing);
    });

    testWidgets('★ 격차가 크면 문구로 알린다 — 색만으로 표시하지 않는다', (tester) async {
      await pump(
        tester,
        BusDistanceComparison(
          plans: measured,
          busNameOf: (id) => const {3: '2호차', 8: '테스트6석', 9: '테스트3석'}[id]!,
        ),
      );

      expect(find.text('버스별 운행거리'), findsOneWidget);
      expect(find.text('7.5km'), findsOneWidget);
      // 막대 색이 아니라 태그와 문장이 어느 노선이 긴지를 말한다(§0-1).
      expect(find.text('최장'), findsOneWidget);
      expect(find.text('최단'), findsOneWidget);
      expect(find.textContaining('2.2배'), findsOneWidget);
    });

    testWidgets('★ 오류로 그리지 않는다 — 정상 동작이고 관리자의 판단 사항이다', (tester) async {
      await pump(tester, BusDistanceComparison(plans: measured));

      // 빨강으로 띄우면 관리자가 제안을 다시 받는다. 다시 받아도 결과는 같다.
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.byIcon(Icons.balance), findsOneWidget);
      expect(find.textContaining('확정 전에 배정을 조정하세요'), findsOneWidget);
    });

    testWidgets('균형이 잡혀 있으면 최장·최단 표식도 안내 문구도 없다', (tester) async {
      await pump(
        tester,
        BusDistanceComparison(
          plans: [
            planOf(id: 1, busId: 3, distanceM: 3500),
            planOf(id: 2, busId: 8, distanceM: 4000),
          ],
        ),
      );

      expect(find.text('버스별 운행거리'), findsOneWidget);
      expect(find.text('최장'), findsNothing);
      expect(find.byIcon(Icons.balance), findsNothing);
    });

    testWidgets('글자 200% 확대에서도 깨지지 않는다', (tester) async {
      await pump(tester, BusDistanceComparison(plans: measured), scale: 2);

      expect(tester.takeException(), isNull);
    });
  });

  group('BusDistanceSpread', () {
    test('최장·최단과 배율을 낸다', () {
      final spread = BusDistanceSpread.of([
        planOf(distanceM: 3500),
        planOf(distanceM: 7529),
        planOf(distanceM: 3815),
      ]);

      expect(spread.longestM, 7529);
      expect(spread.shortestM, 3500);
      expect(spread.ratioLabel, '2.2배');
      expect(spread.isUneven, isTrue);
    });

    test('한 대뿐이면 격차가 없다', () {
      final spread = BusDistanceSpread.of([planOf(distanceM: 3500)]);

      expect(spread.ratio, 1);
      expect(spread.isUneven, isFalse, reason: '비교 대상이 없다');
    });

    test('1.5배 미만은 알리지 않는다 — 정상 편차에 매번 경고를 띄우지 않는다', () {
      final spread = BusDistanceSpread.of([
        planOf(distanceM: 3500),
        planOf(distanceM: 5000),
      ]);

      expect(spread.ratio, closeTo(1.43, 0.01));
      expect(spread.isUneven, isFalse);
    });

    test('★ 거리 0 인 노선이 섞여도 Infinity 를 화면에 흘리지 않는다', () {
      final spread = BusDistanceSpread.of([
        planOf(distanceM: 0),
        planOf(distanceM: 5000),
      ]);

      expect(spread.ratio, 1);
      expect(spread.ratioLabel, '1.0배');
      expect(spread.isUneven, isFalse);
    });

    test('빈 목록도 견딘다', () {
      final spread = BusDistanceSpread.of(const []);

      expect(spread.count, 0);
      expect(spread.isUneven, isFalse);
    });
  });
}
