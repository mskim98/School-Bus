import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/api/spec/session_refresher.dart';
import 'features/auth/application/auth_session_refresher.dart';

/// 앱 전역 초기화.
///
/// 화면을 띄우기 전에 "한 번만" 해야 하는 일을 여기 모은다 — 초기화가 여러 군데로
/// 흩어지면 순서 의존이 생겨 원인을 못 찾는 버그가 난다.
///
/// 흐름:
///  1. Flutter 엔진 바인딩 초기화
///  2. 전역 에러 핸들러 등록 (위젯 에러 · 비동기 에러)
///  3. ProviderScope(= Riverpod 컨테이너)로 앱을 감싸 실행
///
/// ProviderScope 는 Spring 의 ApplicationContext 에 해당한다 —
/// 앱 전체가 여기서 의존성을 꺼내 쓰고, 테스트에서는 `overrides` 로 갈아끼운다.
Future<void> bootstrap() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // 위젯 트리 안에서 터진 에러. 기본 동작(콘솔 출력)을 유지하되 한 군데를 거치게 해
      // 나중에 크래시 리포팅을 붙일 지점을 만들어 둔다.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _report(details.exception, details.stack);
      };

      // 위젯 트리 "밖"(플랫폼 채널 등)에서 터진 에러.
      PlatformDispatcher.instance.onError = (error, stack) {
        _report(error, stack);
        return true;
      };

      runApp(
        ProviderScope(
          // 합성 지점(composition root) — core 가 선언만 해둔 포트에 실제 구현을 꽂는다.
          // core 는 features 를 import 하지 않으므로(컨벤션 C-1) 배선은 여기서만 한다.
          overrides: [
            sessionRefresherProvider.overrideWith(
              (ref) => AuthSessionRefresher(ref),
            ),
          ],
          child: const SchoolBusApp(),
        ),
      );
    },
    // runZonedGuarded 는 위 두 핸들러가 못 잡는 비동기 에러의 마지막 그물이다.
    _report,
  );
}

/// 처리되지 않은 에러의 단일 통로. 지금은 콘솔 출력뿐이지만,
/// 크래시 리포팅(Sentry 등)을 붙일 때 이 함수 하나만 고치면 된다.
void _report(Object error, StackTrace? stack) {
  if (kDebugMode) {
    debugPrint('[unhandled] $error\n$stack');
  }
}
