import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/core/api/api_exception.dart';
import 'package:school_bus/core/ui/async_section.dart';
import 'package:school_bus/core/ui/empty_view.dart';
import 'package:school_bus/core/ui/loading_view.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

void main() {
  group('AsyncSection — 세 갈래를 빠짐없이 그린다', () {
    testWidgets('loading 이면 LoadingView', (tester) async {
      await _pump(
        tester,
        AsyncSection<int>(
          value: const AsyncValue.loading(),
          data: (value) => Text('$value'),
        ),
      );

      expect(find.byType(LoadingView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('error 면 서버 message 를 그대로 보여준다 — 임의로 다시 쓰지 않는다', (
      tester,
    ) async {
      // 컨벤션 §7-2: message 는 사용자에게 보여주는 용도다.
      await _pump(
        tester,
        AsyncSection<int>(
          value: AsyncValue.error(
            ApiException.network('서버에 연결할 수 없습니다'),
            StackTrace.empty,
          ),
          data: (value) => Text('$value'),
        ),
      );

      expect(find.text('서버에 연결할 수 없습니다'), findsOneWidget);
    });

    testWidgets('data 면 builder 결과', (tester) async {
      await _pump(
        tester,
        AsyncSection<int>(
          value: const AsyncValue.data(3),
          data: (value) => Text('$value호차'),
        ),
      );

      expect(find.text('3호차'), findsOneWidget);
    });

    testWidgets('★ onRetry 를 주면 재시도 버튼이 눌린다 — 없으면 사용자가 앱 재시작밖에 못 한다', (
      tester,
    ) async {
      var retried = 0;

      await _pump(
        tester,
        AsyncSection<int>(
          value: AsyncValue.error(
            ApiException.network('서버에 연결할 수 없습니다'),
            StackTrace.empty,
          ),
          onRetry: () => retried++,
          data: (value) => Text('$value'),
        ),
      );
      await tester.tap(find.text('다시 시도'));

      expect(retried, 1);
    });

    testWidgets('onRetry 가 없으면 재시도 버튼도 없다', (tester) async {
      await _pump(
        tester,
        AsyncSection<int>(
          value: AsyncValue.error(
            ApiException.network('서버에 연결할 수 없습니다'),
            StackTrace.empty,
          ),
          data: (value) => Text('$value'),
        ),
      );

      expect(find.text('다시 시도'), findsNothing);
    });
  });

  group('EmptyView — 빈 상태는 에러가 아니다', () {
    testWidgets('제목·설명·아이콘을 모두 보여준다', (tester) async {
      await _pump(
        tester,
        const EmptyView(
          icon: Icons.groups_outlined,
          title: '오늘 태울 학생이 없습니다',
          description: '결석 신고된 학생은 명단에서 자동으로 빠집니다.',
        ),
      );

      expect(find.text('오늘 태울 학생이 없습니다'), findsOneWidget);
      expect(find.text('결석 신고된 학생은 명단에서 자동으로 빠집니다.'), findsOneWidget);
      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    });

    testWidgets('action 을 주면 함께 그린다', (tester) async {
      await _pump(
        tester,
        EmptyView(
          icon: Icons.route_outlined,
          title: '배포된 노선이 없습니다',
          description: '관리자가 노선을 배포하면 여기에 표시됩니다.',
          action: FilledButton(onPressed: () {}, child: const Text('새로고침')),
        ),
      );

      expect(find.text('새로고침'), findsOneWidget);
    });
  });

  group('LoadingView', () {
    testWidgets('label 이 없으면 인디케이터만 — 짧은 로딩에 문구가 깜빡이지 않게', (tester) async {
      await _pump(tester, const LoadingView());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('label 을 주면 함께 보여준다', (tester) async {
      await _pump(tester, const LoadingView(label: '노선을 불러오는 중'));

      expect(find.text('노선을 불러오는 중'), findsOneWidget);
    });
  });
}
