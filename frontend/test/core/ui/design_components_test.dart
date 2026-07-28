import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/app/theme/app_colors.dart';
import 'package:school_bus/app/theme/app_spacing.dart';
import 'package:school_bus/app/theme/app_theme.dart';
import 'package:school_bus/core/ui/app_action_button.dart';
import 'package:school_bus/core/ui/app_status_chip.dart';
import 'package:school_bus/core/ui/app_tone.dart';
import 'package:school_bus/core/ui/offline_banner.dart';
import 'package:school_bus/core/ui/skeleton_box.dart';

Future<void> _pump(WidgetTester tester, Widget child, {ThemeData? theme}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light,
        home: Scaffold(
          body: Center(child: SizedBox(width: 240, child: child)),
        ),
      ),
    );

void main() {
  group('AppStatusChip — 색만으로 상태를 구분하지 않는다', () {
    testWidgets('아이콘과 라벨을 항상 함께 낸다', (tester) async {
      // 디자인 시스템 §0-1: 직사광선·색각 이상 대응. 색이 안 보여도
      // 읽을 수 있어야 하므로 아이콘 문자와 라벨이 같이 나와야 한다.
      await _pump(
        tester,
        const AppStatusChip(icon: '↑', label: '승차 완료', tone: AppTone.primary),
      );

      expect(find.text('↑ 승차 완료'), findsOneWidget);
    });

    testWidgets('★ 탭할 수 없다 — 상태 표기가 눌리면 그걸로 상태를 바꾼다고 오해한다', (tester) async {
      await _pump(
        tester,
        const AppStatusChip(icon: '·', label: '대기', tone: AppTone.neutral),
      );

      expect(
        find.descendant(
          of: find.byType(AppStatusChip),
          matching: find.byWidgetPredicate(
            (w) => w is InkWell || w is GestureDetector,
          ),
        ),
        findsNothing,
      );
    });
  });

  group('AppTone — 확장 색은 필요한 톤에서만 읽는다', () {
    testWidgets('★ AppColors 가 없는 테마에서도 neutral·primary·error 는 산다', (
      tester,
    ) async {
      // 확장을 switch 밖에서 미리 꺼내면 error 하나 쓰는 위젯까지
      // ThemeExtension 등록에 묶여, 색과 무관한 이유로 테스트가 죽는다.
      await _pump(
        tester,
        Builder(
          builder: (context) => Text(
            '${AppTone.neutral.container(context)}'
            '${AppTone.primary.solid(context)}'
            '${AppTone.error.onContainer(context)}',
          ),
        ),
        theme: ThemeData(useMaterial3: true), // AppColors 미등록
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('success·warning 은 AppColors 에서 온다 — M3 ColorScheme 에 없다', (
      tester,
    ) async {
      late Color success;
      late Color warning;

      await _pump(
        tester,
        Builder(
          builder: (context) {
            success = AppTone.success.container(context);
            warning = AppTone.warning.container(context);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(success, AppColors.light.successContainer);
      expect(warning, AppColors.light.warningContainer);
    });
  });

  group('AppActionButton — 운전석에서 눌린다', () {
    testWidgets('기본 높이가 48 이상이다', (tester) async {
      await _pump(
        tester,
        AppActionButton(
          label: '승차',
          icon: '↑',
          tone: AppTone.primary,
          onPressed: () {},
        ),
      );

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(AppTouch.min));
    });

    testWidgets('주요 동작은 56 이다', (tester) async {
      await _pump(
        tester,
        AppActionButton(
          label: '운행 시작',
          tone: AppTone.primary,
          primaryAction: true,
          onPressed: () {},
        ),
      );

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(AppTouch.primary));
    });

    testWidgets('★ 전송 중에는 눌리지 않는다 — 학부모 알림이 걸린 기록이라 중복이 곧 사고다', (tester) async {
      var taps = 0;

      await _pump(
        tester,
        AppActionButton(
          label: '승차',
          tone: AppTone.primary,
          busy: true,
          onPressed: () => taps++,
        ),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('outlined 는 톤 색을 테두리와 글자에 쓴다', (tester) async {
      await _pump(
        tester,
        AppActionButton(
          label: '다시 시도',
          tone: AppTone.error,
          outlined: true,
          onPressed: () {},
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  testWidgets('AppActionDone — 확정 표시는 버튼이 아니다', (tester) async {
    await _pump(tester, const AppActionDone());

    expect(find.text('✓ 완료'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  group('SkeletonList — 스피너 대신 자리표시자', () {
    testWidgets('itemCount 만큼 그린다', (tester) async {
      await _pump(tester, const SkeletonList(itemCount: 5));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SkeletonBox), findsNWidgets(5));
    });

    testWidgets('header 를 주면 하나 더 그린다', (tester) async {
      await _pump(tester, const SkeletonList(itemCount: 3, header: 56));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SkeletonBox), findsNWidgets(4));
    });
  });

  testWidgets('OfflineBanner — 없는 기능을 약속하지 않는다', (tester) async {
    // 시안 문구는 "기록은 저장 후 재전송됩니다" 인데 재전송 큐가 없다.
    // 그대로 쓰면 거짓 안심을 준다(DESIGN_SYSTEM.md §8).
    await _pump(tester, const OfflineBanner());

    expect(find.textContaining('연결이 끊겼습니다'), findsOneWidget);
    expect(find.textContaining('재전송됩니다'), findsNothing);
  });
}
