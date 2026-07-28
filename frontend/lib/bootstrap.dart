import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/app.dart';
import 'core/api/api_config.dart';
import 'core/api/spec/session_refresher.dart';
import 'core/location/impl/location_source_factory_impl.dart';
import 'core/location/spec/location_source_factory.dart';
import 'core/map/impl/flutter_map_adapter.dart';
import 'core/map/spec/map_view_adapter.dart';
import 'core/storage/impl/secure_token_storage.dart';
import 'core/storage/spec/token_storage.dart';
import 'core/ws/impl/stomp_gateway_impl.dart';
import 'core/ws/spec/stomp_gateway.dart';
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
          //
          // **이 목록이 앱의 배선도다.** 포트의 provider 를 구현체 파일에 두면 소비자가
          // `impl/...` 을 import 하게 되고, 그러면 구현을 갈아끼울 때 호출부를 전부 고쳐야 해
          // 포트를 만든 의미가 사라진다(컨벤션 §5). 그래서 구현을 아는 파일은 여기 하나뿐이다.
          //
          // 기본 구현을 두지 않고 spec 쪽에서 UnimplementedError 를 던지게 한 이유 —
          // 배선 누락은 조용히 넘어가는 것보다 첫 사용 시점에 바로 터지는 게 낫다.
          overrides: [
            sessionRefresherProvider.overrideWith(
              (ref) => AuthSessionRefresher(ref),
            ),
            tokenStorageProvider.overrideWithValue(
              const SecureTokenStorage(FlutterSecureStorage()),
            ),
            mapViewAdapterProvider.overrideWithValue(const FlutterMapAdapter()),
            locationSourceFactoryProvider.overrideWithValue(
              const LocationSourceFactoryImpl(),
            ),
            stompGatewayProvider.overrideWith((ref) {
              final gateway = StompGatewayImpl(
                url: ApiConfig.wsUrl,
                tokenStorage: ref.watch(tokenStorageProvider),
                // ⚠️ `read` 로 늦게 꺼낸다 — `apiClientProvider` 와 같은 이유로,
                // 재발급 구현이 다시 이 그래프를 참조해도 순환이 성립하지 않게 하기 위함이다.
                refreshTokens: () =>
                    ref.read(sessionRefresherProvider).refresh(),
              );
              ref.onDispose(gateway.dispose);
              return gateway;
            }),
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
