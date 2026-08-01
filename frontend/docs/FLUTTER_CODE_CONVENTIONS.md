# Flutter Frontend Convention (v1.0)

> **문서 성격**: 프론트엔드 코드 컨벤션의 단일 소스. 백엔드 `backend/docs/reference.md`의 프론트 대응판이며 **원칙을 공유**한다.
> Claude가 매 세션 재참조하므로 토큰 효율을 위해 Markdown 으로 유지한다(HTML 렌더는 만들지 않는다).
>
> **두 가지 용도로 쓴다.**
> 1. **작성 전 조회** — 코드를 쓰기 전에 §1~§8을 읽는다.
> 2. **작성 후 검사** — `convention-auditor` 에이전트가 §9 체크리스트를 그대로 훑어 위반을 찾는다.
>    에이전트 호출 시 이 문서 경로를 명시하고 "§9 체크리스트 기준으로 검사"라고 지시할 것.
>
> 기능 계획·진행 추적은 `FLUTTER_FRONTEND_PLAN.md`(별도). 이 문서는 **어떻게 쓰는가**만 다룬다.

---

## 1. 설계 원칙

백엔드 `reference.md` §1과 동일한 목표를 프론트에 적용한다.

- **변경 가능성이 있는 부분만 추상화한다** — 모든 클래스에 인터페이스를 만드는 게 목적이 아니다
- **구현보다 인터페이스에 의존한다** — 화면은 `dio`·`stomp`·`geolocator`를 직접 알지 않는다
- **OCP** — 새 기능은 기존 코드 수정이 아니라 새 구현체·새 provider 추가로 만든다
- **단방향 의존** — `presentation → application → data → core`. 역방향 import 금지
- **서버 계약 변화가 화면까지 번지지 않게 한다** — DTO와 화면 사이에 경계를 둔다(§4)

---

## 2. 폴더 구조

```
lib/
├── main.dart                 # 진입점. runApp 호출만
├── bootstrap.dart            # 전역 초기화·에러 핸들링·ProviderScope 구성
│
├── app/                      # 앱 셸 — 개별 기능 화면을 두지 않는다
│   ├── app.dart              # MaterialApp.router
│   ├── router/
│   │   ├── app_router.dart   # go_router 정의
│   │   ├── app_routes.dart   # 경로 상수 (문자열 하드코딩 금지)
│   │   └── role_redirect.dart# 역할별 진입 분기·미로그인 차단
│   └── theme/
│       ├── app_theme.dart
│       └── app_spacing.dart  # 간격·반경 토큰 (매직넘버 금지)
│
├── core/                     # 기술 계층 = 백엔드의 infrastructure
│   ├── api/
│   │   ├── api_config.dart   # baseUrl·wsUrl (dart-define 주입)
│   │   ├── api_client.dart   # dio 인스턴스 조립
│   │   ├── api_response.dart # {success,data,message} 언랩
│   │   ├── api_exception.dart# HTTP status → 앱 예외
│   │   └── interceptor/
│   ├── ws/       spec/ impl/ # STOMP 게이트웨이(포트)
│   ├── storage/  spec/ impl/ # 토큰 보관(포트)
│   ├── map/      spec/ impl/ # 지도 어댑터(포트)
│   ├── location/ spec/ impl/ # 기사 위치 소스(포트) — Mock/GPS
│   ├── ui/                   # 공용 위젯(로딩·에러·빈상태)
│   └── util/                 # 순수 함수 유틸(외부 의존 없음)
│
├── features/<feature>/       # 백엔드 모듈명과 1:1 (auth·location·rideevent·routing·notification)
│   ├── data/
│   │   ├── dto/              # 서버 계약 그대로 (freezed)
│   │   └── *_repository.dart # HTTP 호출만
│   ├── domain/               # 앱이 쓰는 모델 (필요할 때만, §4)
│   ├── application/          # provider / notifier — 상태 규칙
│   └── presentation/
│       ├── screen/
│       └── widget/
│
└── shared/domain/            # 여러 feature 가 공유하는 모델 (Role, AuthSession 등)
```

**features 이름은 백엔드 모듈명을 그대로 쓴다.** "이 화면이 어느 백엔드 모듈을 부르는지"를 폴더만 보고 알 수 있게 하기 위함이다.

---

## 3. 계층 규칙 — 백엔드 대응

| 백엔드 | 프론트 | 해도 되는 일 | 하면 안 되는 일 |
|---|---|---|---|
| Controller | `presentation/` (Screen·Widget) | 표시, 사용자 입력 수집, provider 구독 | 비즈니스 판단, `dio`/`Dio` 직접 호출, DTO 조립 |
| Service | `application/` (Notifier·Provider) | 상태 전이, 화면 흐름 규칙, repository 조합 | `dio`·`stomp`·`geolocator` 직접 사용, `BuildContext` 의존 |
| Repository | `data/*_repository.dart` | HTTP 호출, DTO ↔ 모델 변환 | 비즈니스 로직, 상태 보관, 위젯 참조 |
| Infrastructure | `core/` | 외부 기술(dio·stomp·secure_storage·flutter_map) | 특정 feature 지식 |
| DTO | `data/dto/` | 서버 JSON 매핑 | 화면 표시 로직, 기본값으로 결손 은폐 |

**핵심**: `presentation`은 `application`만 본다. `application`은 `data`만 본다. **화면이 `dio`를 import 하면 그 자체로 위반이다.**

---

## 4. DTO / domain 분리 기준 ★

백엔드 `reference.md` §2("구현이 변경될 가능성이 있는가")와 **같은 판단 기준**을 쓴다. 모든 DTO에 도메인 모델을 짝지어 만들지 않는다.

**domain 모델을 만드는 경우** — 서버 표현을 화면이 그대로 쓰기 어렵거나, 서버가 바뀔 여지가 있을 때:

| 사례 | 이유 |
|---|---|
| `RoutePlanResponse.polyline` (JSON **문자열**, `[lng, lat]` 순서) | `List<LatLng>`로 바꿔야 화면이 쓴다. 파싱을 화면에서 하면 안 된다 |
| JWT `memberships: ["1:ACADEMY_ADMIN"]` | `AuthSession{userId, role, tenantId?}`로 해석해야 의미가 생긴다 |
| 여러 API 응답을 합쳐야 완성되는 화면 모델 | 조합 결과는 DTO가 아니다 |

**만들지 않는 경우** — 서버 표현이 이미 화면에 맞는 단순 응답. `BusResponse`, `NotificationResponse` 등은 DTO를 그대로 쓴다.

> 변환은 **repository 에서** 한다(`toDomain()`). application·presentation 에서 파싱하지 않는다.

---

## 5. Port(spec/impl) 규칙

백엔드 §15와 동일하게, **교체 가능성이 있는 기술만** `spec/`(추상) + `impl/`(구현)으로 나눈다.

| Port (`core/*/spec/`) | 구현 후보 | 왜 포트인가 |
|---|---|---|
| `LocationSource` | `MockLocationSource`, `GpsLocationSource` | 기사 화면에서 토글, Phase 8에서 실 GPS 전환 |
| `MapViewAdapter` | `FlutterMapAdapter` (후보: Naver, Google) | `flutter_naver_map`이 Web 미지원이라 지금은 OSM. 나중에 교체 가능해야 함 |
| `TokenStorage` | `SecureTokenStorage` (후보: 인메모리 — 테스트용) | 테스트에서 Mock 필요 |
| `StompGateway` | `StompGatewayImpl` (후보: Fake — 테스트용) | 실시간 동작을 테스트에서 대체해야 함 |

**포트를 만들지 않는 경우**: 구현이 하나뿐이고 바뀔 이유가 없는 것. 예) `ApiConfig`, 각 feature 의 repository(서버가 하나뿐).

**구현체 교체 원칙(백엔드 §5와 동일)**: 새 구현체를 추가할 때 **기존 구현체와 호출부를 수정하지 않는다.**

---

## 6. 네이밍

| 대상 | 규칙 | 예 |
|---|---|---|
| 파일 | `snake_case.dart` | `auth_interceptor.dart` |
| 클래스 | `UpperCamelCase` | `RidePlanRepository` |
| 변수·함수 | `lowerCamelCase` | `reportLocation()` |
| 상수 | `lowerCamelCase` (Dart 관례, `SCREAMING_CAPS` 아님) | `defaultPollInterval` |
| private | `_` 접두 | `_ConfigRow` |
| DTO | `<도메인><용도>Dto` | `RoutePlanDto`, `LoginRequestDto` |
| Provider | `<대상>Provider` | `authSessionProvider` |
| Notifier | `<대상>Notifier` | `RidePlanNotifier` |
| 화면 | `<기능>Screen` | `DriverRouteScreen` |
| 포트 | 기술중립 명사 (`Impl`·기술명 금지) | ⭕ `TokenStorage` ❌ `SecureStorageService` |
| 이벤트 | **과거형** (백엔드 §14와 동일) | `RideRecordedEvent` |

---

## 7. 에러·상태 처리

1. **에러 분기는 HTTP status 로만 한다.** 백엔드 실패 응답에 `errorCode` 필드가 없다 — `message` 문자열을 파싱해 분기하는 코드는 금지.
2. `message`는 **사용자에게 그대로 보여주는 용도**다. 임의로 다시 쓰지 않는다.
3. 비동기 상태는 `AsyncValue`로 다루고, 화면은 **loading / error / data 세 갈래를 반드시 모두 처리**한다. `core/ui`의 공용 위젯을 쓰고 화면마다 다르게 만들지 않는다.
4. 빈 배열은 에러가 아니다 — 빈 상태 UI로 처리한다(자녀 없음·기록 없음 등은 정상 응답).
5. **`try { } catch (_) { }`로 삼키지 않는다.** 처리하지 않을 예외는 올려보낸다.

---

## 8. 금지 사항

- 화면에서 `dio`·`http`·`stomp_dart_client`·`geolocator` 직접 import
- 하드코딩된 경로 문자열 (`context.go('/admin')` → `AppRoutes.admin` 사용)
- 하드코딩된 숫자 간격/색상 (`app/theme` 토큰 사용)
- 하드코딩된 `busId`·`tenantId` (세션에서 가져온다)
- `print()` (로깅은 `core`의 로깅 경로로)
- 서버 응답 필드명을 화면에서 문자열 키로 직접 접근 (`json['data']['busId']`) — DTO를 거친다
- `application`·`presentation`에서 JSON 파싱 (§4)
- 한 파일에 여러 public 클래스를 몰아넣기 (위젯 분리)

---

## 9. 컨벤션 검사 체크리스트 (에이전트용)

> `convention-auditor` 에이전트에게 **이 절을 기준으로 검사**하라고 지시한다.
> 각 항목은 검색으로 확인 가능하게 썼다. 위반 발견 시 `파일:줄번호` + 해당 규칙 번호를 보고한다.

### C-1. 계층 위반 (최우선)
- [ ] `lib/features/*/presentation/**` 에서 `package:dio`·`stomp_dart_client`·`geolocator`·`flutter_secure_storage` import → **위반** (§3, §8)
- [ ] `lib/features/*/application/**` 에서 위 패키지 import → **위반** (§3)
- [ ] `lib/features/*/application/**` 에서 `package:flutter/material.dart` import → **위반** (상태 계층이 위젯을 알면 안 됨)
- [ ] `lib/core/**` 에서 `lib/features/**` import → **위반** (core 는 feature 를 몰라야 함)
- [ ] feature A 의 코드가 feature B 의 `data/`·`application/` 을 직접 import → **위반** (공용은 `shared/` 로)
  - **허용되는 단 하나의 예외: `presentation/` 이 다른 feature 의 `application/` provider 를 `ref.watch` 해 그 값을 아래로 넘기는 경우.** 기사 화면은 노선·명단·위치가 한 화면 안에서 서로를 참조해야 성립하는데(지도 마커 번호 = 명단 그룹 번호, 정차 진행률 = 승하차 상태), 이걸 상태 계층에서 엮으면 두 컨트롤러가 서로를 다시 빌드시켜 무한 루프가 되거나 한쪽 로딩이 다른 쪽을 막는다. 그래서 **조립만 화면에서 하고, application/domain/data 는 계속 서로를 모른다.**
  - 조건 3개를 모두 지켜야 예외다: ① import 하는 쪽이 `presentation/` 일 것 ② 읽기(`ref.watch`)만 하고 다른 feature 의 컨트롤러 메서드를 **호출하지 않을** 것 ③ 상대가 없거나 로딩 중이어도 **내 화면은 그려질 것**(예: 노선이 없으면 명단 그룹 번호를 1부터 매긴다)
  - 선례: `DriverLocationCard(mockPath:)`(`features/location/presentation/widget/driver_location_card.dart:18-19`), `DriverRosterScreen` ↔ `DriverRouteScreen` 의 정차 그룹 번호 공유(`DESIGN_SYSTEM.md` §5.4-4)
  - ⚠️ `features/rideevent/application/driver_roster_controller.dart` → `features/drivesession/application/` 은 이 예외에 **해당하지 않는 기존 위반**이다. 파일 상단 주석대로 언젠가 `shared/` 로 올려야 한다 — 새 코드가 이걸 선례로 삼지 마라

### C-2. DTO / 파싱
- [ ] `presentation/`·`application/` 에 `jsonDecode`·`json[` 문자열 키 접근 → **위반** (§4, §8)
- [ ] repository 밖에서 `toDomain()`류 변환 수행 → **위반** (§4)
- [ ] DTO 필드에 근거 없는 기본값(`?? 0`, `?? ''`)으로 결손을 은폐 → **검토 대상** (§3)

### C-3. 에러 처리
- [ ] `message` 문자열을 `contains`/`==` 로 비교해 분기 → **위반** (§7-1)
- [ ] `catch` 블록이 비어 있거나 로그만 남기고 삼킴 → **위반** (§7-5)
- [ ] `AsyncValue` 사용처에서 `error`/`loading` 분기 누락 → **위반** (§7-3)

### C-4. 하드코딩
- [ ] `context.go('/...')`·`GoRoute(path: '/...')` 외의 경로 문자열 리터럴 → **위반** (§8)
- [ ] `busId`·`tenantId` 에 정수 리터럴 대입 (테스트 제외) → **위반** (§8)
- [ ] `EdgeInsets`·`SizedBox` 등에 테마 토큰 아닌 매직넘버 반복 → **검토 대상** (§8)
- [ ] `print(` 사용 → **위반** (§8)

### C-5. 포트 규칙
- [ ] `core/*/impl/` 의 구현체를 `spec/` 대신 직접 참조 → **위반** (§5)
- [ ] 포트 이름에 기술명 포함 (`...SecureStorage`, `...DioClient`) → **위반** (§6)
- [ ] 구현이 하나뿐이고 교체 계획도 없는데 spec/impl 로 나눔 → **과잉 추상화, 검토 대상** (§5)

### C-6. 네이밍·구조
- [ ] 파일명이 `snake_case` 가 아님 → **위반** (§6)
- [ ] 이벤트 클래스가 과거형이 아님 → **위반** (§6)
- [ ] 한 파일에 서로 무관한 public 클래스 2개 이상 → **검토 대상** (§8)

### C-7. 기계 검사 (에이전트가 실행)
```bash
cd frontend
flutter analyze                 # 무경고여야 한다
dart format --set-exit-if-changed lib/   # 포맷 미적용 파일이 있으면 실패
```

### C-8. 디자인 시스템 (담당: `design-system-auditor`)

> 근거 문서는 **[`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md)** 다. 지적할 때 절 번호를 같이 댄다.
> C-1~C-7 은 `convention-auditor`, C-8 은 `design-system-auditor` 가 본다 — **중복 지적하지 않는다.**
> 검사 대상은 `presentation/`·`core/ui/`·`app/theme/`·`app/shell/` 뿐이다(`data`·`application`·`domain` 은 화면을 그리지 않는다).

**High — 사용자가 잘못 판단할 수 있는 것**
- [ ] 상태를 **색만으로** 구분 (아이콘·텍스트 라벨 없음) → **위반** (§0-1, §4)
- [ ] 서버 응답 전에 상태를 확정 표시 (낙관적 UI) → **위반** (§0-2, §4.2). `전송 중` 표시가 없으면 의심한다
- [ ] 탭 가능한 요소 높이/터치영역이 **48dp 미만** → **위반** (§3.3)
- [ ] 승하차 상태의 라벨 문자열·아이콘이 §4 표와 다름 → **위반**. `대기`/`승차 완료`/`하차 완료`/`보호자 인계 완료` 외 문자열 금지
- [ ] `RideStatusChip` 을 쓰지 않고 화면에서 상태 칩을 다시 만듦 → **위반** (§7-3)

**Medium — 시스템 이탈**
- [ ] `app/theme/` 밖에서 `Color(0x…)` 리터럴 → **위반** (§7-1)
- [ ] `app/theme/` 밖에서 `TextStyle(fontSize: …)` 직접 생성 → **위반** (§7-2)
- [ ] `EdgeInsets`·`SizedBox`·`BorderRadius` 에 `AppSpacing` 아닌 숫자 리터럴 → **위반** (§7-6)
- [ ] 반경 용도 어긋남 — 칩 8 / 버튼·입력·행 12 / 카드·시트 20 (§3.2)
- [ ] 지도 배경에 `surface` 계열 재사용 (`AppColors.mapBase`/`mapLine` 이 있다) → **위반** (§1.3)
- [ ] `etaSeconds` 를 초 단위 그대로 노출 → **위반** (§7-8)

**Low — 일관성**
- [ ] 데이터 로딩에 전체화면 스피너 (스켈레톤이 있다) → **검토 대상** (§6). 단 **버튼 안의 인디케이터는 정상**이다(화면 로딩이 아니라 동작 진행 표시)
- [ ] 빈 상태에 "다음 행동" 버튼이 없음 → **검토 대상** (§6)
- [ ] `Row` 고정폭 때문에 텍스트 200% 확대에서 깨짐 → **검토 대상** (§7-5)

**지적하지 않는 것**
- 문서에 근거가 없는 미적 취향
- 지시서 §7 이 금지한 데이터(사진·연락처·통계)를 **안 쓴 것** — 그게 정상이다
- 지도 마커 크기·애니메이션 duration 등 §5.3 이 명시한 값

---

## 10. 백엔드 컨벤션과의 관계

| 백엔드 `reference.md` | 프론트 대응 | 비고 |
|---|---|---|
| §2 spec/impl 판단기준 | §5 Port 규칙 | **동일 기준** — "구현이 바뀔 가능성이 있는가" |
| §7 CQRS | **적용 안 함** | 클라이언트에는 과잉. repository 의 read/write 메서드 구분으로 충분 |
| §10 DTO 규칙 | §4 DTO/domain | 방향만 반대(응답 수신) |
| §11 Controller 규칙 | §3 presentation | "표시·입력 수집만" |
| §14 Event 과거형 | §6 네이밍 | 그대로 적용 |
| §15 Port 추상화 표 | §5 표 | 프론트 포트 4개로 재정의 |
| §6 Event 기반(Kafka) | **적용 안 함** | 클라이언트 내부 이벤트 버스를 별도로 두지 않는다 — Riverpod provider 의존성으로 충분 |
