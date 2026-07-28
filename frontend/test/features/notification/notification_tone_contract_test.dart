import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/app/theme/app_theme.dart';
import 'package:school_bus/core/ui/app_tone.dart';
import 'package:school_bus/features/notification/data/dto/notification_dto.dart';
import 'package:school_bus/features/notification/presentation/widget/notification_tile.dart';
import 'package:school_bus/features/rideevent/domain/roster_student.dart';
import 'package:school_bus/features/rideevent/presentation/widget/ride_status_chip.dart';

/// 같은 사건이 **기사 화면과 관리자 화면에서 같은 톤**으로 나오는지 지킨다.
///
/// 2026-07-29 감사에서 실제로 어긋나 있었다 — 관리자 알림함이 승차·하차·인계를
/// 전부 `success`(초록) 로 칠하고 있었다. 하차는 하원에서 아직 인계가 남은
/// **중간 단계**라, 색이 같으면 관리자가 알림 목록만 훑고 "아직 인계 안 된 아이"를
/// 완료로 읽는다. 상태 계약(`docs/DESIGN_SYSTEM.md` §4)이 막으려던 사고 그 자체다.
///
/// 이런 종류의 어긋남은 두 화면을 나눠 만들 때마다 다시 생긴다. 그래서 눈이 아니라
/// 테스트가 지킨다.
void main() {
  Future<Color> circleColorOf(WidgetTester tester, String type) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: NotificationTile(
            notification: NotificationDto(
              id: 1,
              tenantId: 1,
              studentId: 1,
              type: type,
              message: '김민준 학생 알림',
              createdAt: DateTime(2026, 7, 29, 14, 5),
            ),
          ),
        ),
      ),
    );

    // 좌측 유형 아이콘 원 — 톤이 드러나는 유일한 면이다.
    final decorated = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (c) => (c.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        );
    return (decorated.first.decoration! as BoxDecoration).color!;
  }

  /// 기사 화면이 쓰는 톤을 같은 테마에서 색으로 푼다.
  Future<Color> driverToneColorOf(
    WidgetTester tester,
    RideStatus status,
  ) async {
    late Color color;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            color = RideStatusChip.toneOf(status).container(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return color;
  }

  group('★ 승하차 톤은 기사 화면과 관리자 알림함에서 같아야 한다 (§4)', () {
    testWidgets('승차 — 기사 칩과 알림 아이콘이 같은 톤', (tester) async {
      expect(
        await circleColorOf(tester, 'BOARD_DONE'),
        await driverToneColorOf(tester, RideStatus.boarded),
      );
    });

    testWidgets('하차 — 기사 칩과 알림 아이콘이 같은 톤', (tester) async {
      expect(
        await circleColorOf(tester, 'ALIGHT_DONE'),
        await driverToneColorOf(tester, RideStatus.alighted),
      );
    });

    testWidgets('인계 — 기사 칩과 알림 아이콘이 같은 톤', (tester) async {
      expect(
        await circleColorOf(tester, 'HANDOVER_DONE'),
        await driverToneColorOf(tester, RideStatus.handedOver),
      );
    });

    testWidgets('★ 하차와 인계는 서로 다른 색이어야 한다 — 합치면 "인계 안 된 아이"가 완료로 읽힌다', (
      tester,
    ) async {
      final alight = await circleColorOf(tester, 'ALIGHT_DONE');
      final handover = await circleColorOf(tester, 'HANDOVER_DONE');

      expect(alight, isNot(handover));
    });
  });

  testWidgets('§5.2 가 정한 나머지 톤 — 미승차 error · 근접 primary', (tester) async {
    late Color error;
    late Color primary;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            error = AppTone.error.container(context);
            primary = AppTone.primary.container(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(await circleColorOf(tester, 'NO_SHOW'), error);
    expect(await circleColorOf(tester, 'APPROACH'), primary);
  });
}
