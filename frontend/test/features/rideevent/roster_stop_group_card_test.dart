import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/app/theme/app_theme.dart';
import 'package:school_bus/features/drivesession/domain/drive_session.dart';
import 'package:school_bus/features/rideevent/domain/roster_stop_group.dart';
import 'package:school_bus/features/rideevent/domain/roster_student.dart';
import 'package:school_bus/features/rideevent/presentation/widget/roster_stop_group_card.dart';

/// 정차 그룹 카드는 **문구를 스스로 짓지 않는다** — 도메인이 준 걸 그대로 낸다.
/// 여기서 검사하는 건 그 표기가 화면에 실제로 나오는지와, 접힘/펼침 계약이다.
void main() {
  RosterStudent student(
    int id,
    String name, {
    RideStatus status = RideStatus.waiting,
  }) => RosterStudent(
    studentId: id,
    name: name,
    location: '정류장 A',
    status: status,
  );

  RosterStopGroup groupOf(List<RosterStudent> students) => RosterStopGroup(
    seq: 2,
    students: students,
    direction: DriveDirection.pickup,
    label: '정류장 A',
  );

  Future<void> pump(
    WidgetTester tester,
    RosterStopGroup group, {
    bool expanded = true,
    VoidCallback? onToggle,
    double textScale = 1,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: RosterStopGroupCard(
              group: group,
              expanded: expanded,
              onToggle: onToggle ?? () {},
              rowBuilder: (context, s) => Text(s.name),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('헤더가 순번·제목·태그·진행률을 함께 낸다', (tester) async {
    await pump(tester, groupOf([student(1, '김민준'), student(2, '이서연')]));

    expect(find.text('2'), findsOneWidget);
    expect(find.text('정류장 A'), findsOneWidget);
    expect(find.text('승차'), findsOneWidget);
    expect(find.text('승차 2명'), findsOneWidget);
    expect(find.text('0/2명'), findsOneWidget);
  });

  testWidgets('펼치면 학생 행이, 접으면 요약 한 줄이 나온다', (tester) async {
    final group = groupOf([student(1, '김민준'), student(2, '이서연')]);

    await pump(tester, group);
    expect(find.text('김민준'), findsOneWidget);
    expect(find.text(group.collapsedSummary), findsNothing);

    await pump(tester, group, expanded: false);
    expect(find.text('김민준'), findsNothing);
    expect(find.text(group.collapsedSummary), findsOneWidget);
  });

  testWidgets('★ 완료 그룹을 색만으로 구분하지 않는다 — 체크 아이콘과 진행률을 같이 낸다', (tester) async {
    // 디자인 시스템 §0-1. 직사광선 아래 운전석에서 톤 차이는 잘 안 보인다.
    await pump(
      tester,
      groupOf([student(1, '김민준', status: RideStatus.alighted)]),
    );

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('1/1명'), findsOneWidget);
  });

  testWidgets('헤더 전체가 56dp 이상 터치 타깃이다', (tester) async {
    var toggled = 0;
    await pump(tester, groupOf([student(1, '김민준')]), onToggle: () => toggled++);

    final header = find.byType(InkWell);
    expect(tester.getSize(header).height, greaterThanOrEqualTo(56));

    // 화살표가 아니라 헤더 아무 데나 눌러도 열린다 — 흔들리는 차 안에서 조준이 안 된다.
    await tester.tap(find.text('정류장 A'));
    expect(toggled, 1);
  });

  testWidgets('글자 200% 확대에서도 헤더가 넘치지 않는다', (tester) async {
    await pump(
      tester,
      groupOf([student(1, '김민준'), student(2, '이서연')]),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    expect(find.text('정류장 A'), findsOneWidget);
  });
}
