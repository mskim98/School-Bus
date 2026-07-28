# Flutter 컨벤션 감사 (2026-07-29)

- 기준 문서: `frontend/docs/FLUTTER_CODE_CONVENTIONS.md` §9 체크리스트(C-1~C-7)
- 검사 대상: `frontend/lib/` 전체 86개 dart 파일 (`frontend/test/`는 규칙상 제외)
- 특히 집중: 커밋 `33de6e0`(C7~C13, 병렬 에이전트 산출물) — `rideevent`·`drivesession`·`location`·`notification`·`routing`·`core/ws`·`core/location`
- **코드는 수정하지 않았다. 아래는 확인된 사실만 기록한다.**

## 1. 요약

- **위반**: 2건(원인 기준 그룹핑, 실제 파일 수로는 8개 파일)
- **검토 대상**: 4건
- **C-7 기계 검사**: `flutter analyze` — 이상 없음(No issues found). `dart format --output=none --set-exit-if-changed lib/` — 변경 필요 파일 0개(Formatted 86 files (0 changed)). **모두 통과.**

가장 심각한 3건(상세는 2절):
1. **[C-5, 구조적] 포트 4종 전부에서 provider가 `spec/`가 아니라 `impl/` 파일에 정의돼 있어, 소비자 7개 파일이 `core/*/impl/*.dart`를 직접 import한다.** 동작엔 문제 없지만 §5의 취지(구현 교체 시 호출부 무영향)를 구조적으로 훼손한다.
2. **[§3, C-1 인접] `notification_tile.dart:4`가 `data/dto/notification_dto.dart`를 직접 import** — presentation이 application을 건너뛰고 DTO를 참조.
3. **[C-2, 검토대상] DTO 6곳에서 근거 설명 없는 기본값(`?? ''`, `?? 0`)으로 결손을 은폐** — 서버가 필드를 누락해도 조용히 빈 값/0으로 넘어간다.

## 2. 위반

| 파일:줄번호 | 규칙 | 무엇이 문제인가 | 수정 방향 |
|---|---|---|---|
| `lib/features/auth/data/auth_repository.dart:6` | C-5 | `core/storage/impl/secure_token_storage.dart`(구현체)를 직접 import. 원인: `tokenStorageProvider`가 `secure_token_storage.dart`(impl) 안에 정의돼 있어 소비자가 spec만으로 provider에 닿을 수 없음 | `tokenStorageProvider` 정의를 `spec/token_storage.dart` 또는 별도 `core/storage/provider.dart`로 이동 |
| `lib/features/notification/application/notification_feed_controller.dart:5` | C-5 | `core/ws/impl/stomp_gateway_impl.dart` 직접 import(`stompGatewayProvider`가 impl 파일에 있음) | 위와 동일한 방식으로 provider 위치 이동 |
| `lib/features/notification/data/notification_repository.dart:5` | C-5 | 위와 동일 원인 | 위와 동일 |
| `lib/features/location/application/driver_location_controller.dart:6` | C-5 | `core/location/impl/location_source_factory_impl.dart` 직접 import(`locationSourceFactoryProvider`가 impl 파일에 있음) | 위와 동일한 방식으로 provider 위치 이동 |
| `lib/features/location/presentation/screen/admin_monitor_screen.dart:5` | C-5 | `core/map/impl/flutter_map_adapter.dart` 직접 import(`mapViewAdapterProvider`가 impl 파일에 있음) | 위와 동일 |
| `lib/features/routing/presentation/widget/route_plan_map.dart:5` | C-5 | 위와 동일 원인 | 위와 동일 |
| `lib/features/routing/presentation/screen/driver_route_screen.dart:5` | C-5 | 위와 동일 원인 | 위와 동일 |
| `lib/features/notification/presentation/widget/notification_tile.dart:4,18` | §3(계층 규칙, C-1 취지) | presentation 위젯이 `data/dto/notification_dto.dart`의 `NotificationDto`를 직접 import·필드로 보유 — "presentation은 application만 본다" 위반 | `NotificationDto`를 감싸는 화면용 파라미터(간단한 필드 destructure 또는 `shared`에 얇은 view 모델)를 만들어 presentation이 `data/`를 몰라도 되게 함. 단, §4 예외(단순 응답은 DTO 그대로 사용)와 상충 여지가 있어 팀 판단 필요 |

> 위 7건의 C-5 위반은 **원인이 하나(포트 provider가 impl에 위치)** 이므로, provider 정의 위치만 옮기면 한 번에 해결된다. `TokenStorage`/`StompGateway`/`LocationSourceFactory`/`MapViewAdapter` 4개 포트 **전부**에서 동일 패턴이 관찰됨(4/4) — 실수가 아니라 이번 병렬 작업 전반에 적용된 설계 습관으로 보인다.

## 3. 검토 대상

| 파일:줄번호 | 규칙 | 무엇이 문제인가 | 수정 방향 |
|---|---|---|---|
| `lib/features/location/data/dto/bus_location_dto.dart:37,40,41` | C-2 | `busName`·`recordedAt`·`origin`이 `required`(non-nullable) 필드인데 `fromJson`에서 `as String? ?? ''`로 결손을 조용히 은폐 | 서버가 필드를 실제로 생략할 수 있는지 확인. 아니라면 `as String`로 바꿔 계약 위반 시 즉시 실패하게 |
| `lib/features/location/data/dto/bus_summary_dto.dart:25` | C-2 | `name` 필드 `?? ''` — 위와 동일 패턴 | 위와 동일 |
| `lib/features/routing/data/dto/route_plan_dto.dart:48,49,82` | C-2 | `totalDistanceM`·`totalDurationS`·`etaSeconds` `?? 0` — 근거 주석 없음(바로 위 `version`필드의 `?? 1`에는 이유 주석이 있는 것과 대조적) | 근거가 있다면 `version`처럼 주석 추가, 없다면 non-null로 강제 |
| `lib/features/location/domain/monitored_bus.dart:112-158`(`MonitoredBus.merge`), 호출부 `lib/features/location/application/bus_monitor_controller.dart:118,187` | §4("변환은 repository 에서 한다") | `BusPosition.fromDto` 변환이 `application` 계층(`bus_monitor_controller.dart`)에서 호출하는 `MonitoredBus.merge` 내부에서 일어남. 다만 이 병합은 이전 폴링 상태(`previous`)·클라이언트 시계(`observedAt`)에 의존하는 상태 저장 로직이라 repository로 옮기기 애매함 — 의도적 예외일 가능성 있음 | 팀 판단 필요. 옮기기 어렵다면 §4에 "여러 폴링 이력을 참조하는 병합은 application 예외"로 명문화 검토 |
| `lib/features/routing/presentation/screen/admin_dispatch_screen.dart:195,382` | C-4 | `SizedBox(height: 320, child: ...)` — `AppSpacing` 토큰 미사용 매직넘버가 2곳에서 반복 | `AppSpacing`에 필요하면 새 토큰 추가하거나 `admin_monitor_screen.dart`의 `_sidePanelWidth`처럼 파일 내 named const로 승격 |

## 4. 깨끗한 영역 (위반 0건 확인됨 — 재검사 불필요)

- **C-1 계층 위반**: `presentation/`·`application/`에서 `dio`/`stomp_dart_client`/`geolocator`/`flutter_secure_storage` import — 0건. `application/`에서 `flutter/material.dart` import — 0건. `core/`가 `features/`를 import — 0건. feature 간 `data/`·`application/` 교차 import — 0건.
- **C-2 DTO/파싱**: `presentation`·`application`에서 `jsonDecode`/`json[` 문자열 키 접근 — 0건. `fromDto` 변환은 전부 각 feature의 `data/*_repository.dart` 내부에서만 호출(`MonitoredBus.merge` 1건 제외, §3 참조).
- **C-3 에러 처리**: `message` 문자열 `contains`/`==` 로 분기 — 0건(`connection_status_chip.dart:48`의 `message == null`은 null 여부만 보는 표시 로직이지 에러 종류 분기가 아님, 위반 아님으로 확인). `catch` 블록이 비거나 로그만 남기고 삼키는 경우 — 0건(전수 확인, `on Object catch`로 넓게 받는 2곳도 상태 갱신/폴백 반환 등 의미 있는 처리를 함). `AsyncValue` 사용처의 loading/error 분기 누락 — 0건(`login_screen.dart`는 `.when()` 대신 `isLoading`/`hasError`/`value`를 쓰지만 3가지 상태를 모두 다룸).
- **C-4 하드코딩**: `context.go`/`GoRoute(path:` 하드코딩 경로 문자열 — 0건. `busId`/`tenantId` 정수 리터럴 대입(lib/ 전체) — 0건. `print(` 사용 — 0건(주석에서만 언급).
- **C-5 포트 규칙**: 포트 이름에 기술명 포함(`...SecureStorage`, `...DioClient` 류) — 0건. 구현 하나뿐인데 spec/impl로 과잉 분리 — 0건(4개 포트 모두 §5 표에 교체 후보가 명시돼 있음).
- **C-6 네이밍·구조**: 파일명이 snake_case 아님 — 0건(86개 전부 확인). 한 파일에 서로 무관한 public 클래스 2개 이상 — 점검한 18개 파일 모두 관련 있는 짝(State+Notifier, DTO 부모+자식 등)으로 확인, 위반 없음. (`RideEvent`는 클라이언트 내부 이벤트가 아니라 백엔드 엔티티와 1:1 대응하는 도메인 모델명이라 §6 이벤트 과거형 규칙 대상이 아님 — §10에 "클라이언트 내부 이벤트 버스는 두지 않는다"고 명시돼 있어 해당 규칙 자체가 적용 안 됨)
- **C-7 기계 검사**: `flutter analyze` 무경고, `dart format` 미적용 파일 0개. **통과.**

## 5. 심각도 순 권장 조치

1. **(High)** 포트 provider 4종(`TokenStorage`/`StompGateway`/`LocationSourceFactory`/`MapViewAdapter`)의 정의 위치를 `impl/`에서 `spec/`(또는 별도 provider 파일)로 옮긴다. 7개 소비 파일의 import가 한 번에 정리되고, §5가 원래 지키려는 "구현 교체 시 호출부 무수정" 보장이 이름뿐 아니라 실제로 성립하게 된다.
2. **(Medium)** `notification_tile.dart`의 `NotificationDto` 직접 사용을 팀 차원에서 판단한다 — §4 예외(단순 DTO는 그대로 사용) 범위로 인정할지, 아니면 §3 계층 규칙을 엄격히 적용해 얇은 표시용 모델을 추가할지 결정 필요.
3. **(Medium)** DTO 기본값 은폐 6곳 — 서버 계약상 실제로 생략 가능한 필드인지 백엔드와 대조 확인 후, 아니라면 non-null 캐스팅으로 바꿔 결손을 조용히 넘기지 않게 한다.
4. **(Low)** `MonitoredBus.merge` 위치, `SizedBox(height: 320)` 매직넘버 2곳 — 우선순위 낮음, 여유 있을 때 정리.

