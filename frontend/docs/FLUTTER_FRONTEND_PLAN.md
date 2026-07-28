# FLUTTER_FRONTEND_PLAN — 프론트엔드 단일 소스(SoT)

> **문서 성격**: 프론트엔드(Flutter) 작업의 **단일 소스**다. 프론트 관련 작업을 시작할 때 **이 문서를 가장 먼저 읽는다.**
> 백엔드 전체 계획은 `backend/docs/PROJECT_MASTER_PLAN.md`, API 계약은 `backend/docs/MVP_API_SPEC.md`,
> 백엔드 코드 컨벤션은 `backend/docs/reference.md`를 따른다.
>
> **포맷**: Claude가 매 세션 재참조하는 계획·추적 문서이므로 토큰 효율을 위해 **Markdown 유지**
> (루트 `CLAUDE.md`의 "문서 포맷 규칙" 예외 조항 적용 — HTML 렌더는 만들지 않는다).
>
> **작성일**: 2026-07-28 (초안). 진행 상황·설계 변경은 이 문서에 반영한다.

---

## 0. 스코프 (사용자 확정, 2026-07-28)

**MVP 범위까지만 작업한다.** `backend/docs/MVP_RELEASE_TRACKER.md` §0에서 확정한 MVP 대상 사용자 계층을 그대로 따른다.

| 계층 | 포함 | 비고 |
|---|---|---|
| `DRIVER` (기사/선탑자) | ✅ | 모바일 레이아웃 — 노선 확인 · 승하차 기록 · 위치 보고 |
| `ACADEMY_ADMIN` / `PLATFORM_ADMIN` | ✅ | 데스크톱 레이아웃 — 관제 지도 · 배차 · 알림 이력 |
| `STUDENT` / `PARENT` | ❌ **범위 밖** | API는 이미 있음(`MVP_API_SPEC.md` §4.2·4.3·6.2). MVP 이후 확장 |

**MVP 5개 기능**(트래커 §0) 중 프론트가 그리는 것:

| # | 기능 | 담당 화면 |
|---|---|---|
| 1 | 버스 실시간 위치 (F1) | 관리자 관제 지도 + 기사 위치 보고 |
| 2 | 이벤트 기반 노선 재최적화 (F2) | (백엔드 자동) — 프론트는 갱신된 노선 재조회만 |
| 3 | 노선 변경 시 기사 배포 (F3) | 기사 알림 수신 → 노선 재조회 |
| 4 | 배차 최적화 (F4) | 관리자 배차 제안 → 검토 → 확정 |
| 5 | 학생 승하차 | 기사 승하차 기록 화면 |

**하지 않는 것** — 회원가입 UI, 학생/학부모 앱, 수동 노선 생성(`/generate`), 기록 정정, 개인정보 동의 UI(Phase 8 선행요건), 오프라인 모드.

---

## 1. 기술 스택 결정

### 1.1 결정 요약

| 영역 | 채택 | 이유 |
|---|---|---|
| 프레임워크 | **Flutter (stable) / Dart 3** | 사용자 지정 |
| 빌드 타깃 | **Web(주) + Android/iOS(부)** | §1.2 참조 — Docker로 띄우는 건 Web |
| 상태관리 | **Riverpod** (`flutter_riverpod` **only**) | 보일러플레이트가 Bloc보다 적고, `AsyncValue`(loading/error/data)가 내장돼 API 화면에 그대로 맞는다.<br>⚠️ `riverpod_annotation`/`riverpod_generator`는 **제외** — Flutter 3.44.8 번들 analyzer와 버전 충돌(C1). Provider는 손으로 선언 |
| 라우팅 | **`go_router`** | 선언형 + `redirect` 훅으로 "역할별 진입 화면 분기 / 미로그인 차단"을 한 곳에서 처리 |
| HTTP | **`dio`** | interceptor 체인이 있어 JWT 부착·401 자동 refresh를 한 군데로 모을 수 있다 |
| 모델/직렬화 | **불변 클래스 + `fromJson`** | 현재 DTO가 단순해 코드생성 없이 충분하다. `freezed`/`json_serializable`은 의존성에만 두고, 중첩이 깊은 DTO(`RoutePlan.stops[]`)에서 값을 할 때 도입한다 |
| 리버스 프록시 | **nginx** (`:80` 단일 진입점) | §5 — CORS 제거 + 로드밸런싱 확장 지점 |
| 토큰 저장 | **`flutter_secure_storage`** | 모바일은 Keychain/Keystore, 웹은 WebCrypto 기반 저장으로 자동 분기 |
| WebSocket | **`stomp_dart_client`** | 백엔드가 **SockJS 미사용 순수 STOMP**라서 그대로 맞는다 (`MVP_API_SPEC.md` §7.1) |
| 지도 | **`flutter_map`** (OSM 타일) | §1.3 참조 |

### 1.2 ⚠️ Docker와 Flutter — 반드시 짚고 갈 것

**Docker로 "띄울" 수 있는 건 Flutter Web 빌드뿐이다.** 컨테이너 안에서 Android/iOS 앱을 실행할 방법은 없다
(빌드는 컨테이너에서 할 수 있지만, 실행은 에뮬레이터/실기기 몫이다).

따라서 이 프로젝트의 구성은:

- **`docker compose up`** → Flutter **Web** 빌드를 nginx가 정적 서빙 (`localhost:3000`) — 기사 화면·관리자 화면 둘 다 브라우저에서 확인 가능
- **모바일 실기기 확인이 필요할 때** → 같은 코드베이스를 `flutter run`으로 로컬 실행 (Docker 밖)

같은 `lib/`를 공유하므로 코드 이중 관리는 없다. **화면 레이아웃만 반응형으로 분기**한다(기사=좁은 폭, 관리자=넓은 폭).

> 기사 앱이 "진짜 모바일 앱"이어야 한다면 그건 Web으로도 UI 검증은 가능하고, 배포 단계에서 APK/IPA를 뽑으면 된다.
> MVP 단계에서 Docker 기동 대상은 Web 하나로 충분하다.

### 1.3 ⚠️ 지도를 네이버가 아니라 `flutter_map`으로 가는 이유

`flutter_naver_map` 패키지는 **Android/iOS만 지원하고 Web을 지원하지 않는다.** §1.2대로 Web이 주 타깃이므로
네이버 지도를 쓰면 웹에서 지도가 아예 안 뜬다.

- **채택**: `flutter_map`(Leaflet 계열, 순수 Dart) + OpenStreetMap 타일 — Web·모바일 모두 동작, API 키 불필요
- 우리가 지도에 그릴 건 **마커(버스·정류장) + polyline(노선)** 뿐이고, 이 둘은 `flutter_map`으로 충분하다
- **백엔드가 실도로 경로 계산을 이미 네이버로 하고 있고**(`routing.provider=naver`), 프론트는 그 결과 polyline을 받아 그리기만 한다
  → 타일 제공자가 OSM이어도 경로 정확도에는 영향이 없다

**교체 가능하게 둔다**: `core/map/`에 `MapAdapter` 추상(포트)을 두고 `FlutterMapAdapter`를 구현체로 붙인다.
나중에 네이버 지도로 바꿀 때 화면 코드를 안 건드리도록 — 백엔드의 `RouteEngine`/`MapRouteClient` 포트 패턴과 같은 방식이다.

---

## 2. 폴더 구조 · 코드 컨벤션

> **이 절의 상세는 별도 문서로 분리했다 → [`FLUTTER_CODE_CONVENTIONS.md`](FLUTTER_CODE_CONVENTIONS.md)**
> 폴더 레이아웃 · 계층 규칙 · DTO/domain 분리 기준 · Port(spec/impl) 규칙 · 네이밍 · 금지사항 ·
> **에이전트용 컨벤션 검사 체크리스트(§9)** 가 전부 거기 있다. 코드를 쓰기 전에 그 문서를 먼저 읽는다.

요약만 옮기면:

- **feature 이름 = 백엔드 모듈명**(`auth`·`location`·`rideevent`·`routing`·`notification`) — 화면이 어느 백엔드 모듈을 부르는지 폴더만 보고 알 수 있게
- **계층 대응**: `presentation/`=Controller · `application/`=Service · `data/`=Repository · `core/`=Infrastructure
- **단방향 의존**: `presentation → application → data → core`. 화면이 `dio`를 import 하면 그 자체로 위반
- **Port는 교체 가능성이 있는 것만**(백엔드 `reference.md` §2와 같은 기준) — `LocationSource` · `MapViewAdapter` · `TokenStorage` · `StompGateway` 4개

```
frontend/
├── Dockerfile · nginx.conf · .dockerignore   # Flutter Web → nginx (§5)
├── pubspec.yaml
├── docs/
│   ├── FLUTTER_FRONTEND_PLAN.md      # ← 이 문서 (무엇을 만드는가)
│   └── FLUTTER_CODE_CONVENTIONS.md   # 어떻게 쓰는가 + 검사 체크리스트
└── lib/
    ├── main.dart · bootstrap.dart
    ├── app/{router,theme}/
    ├── core/{api,ws,storage,map,location,ui,util}/
    ├── features/<모듈>/{data/dto,domain,application,presentation/{screen,widget}}/
    └── shared/domain/
```

## 3. 백엔드 연동 규약 — ⚠️ 함정 모음

`MVP_API_SPEC.md`를 코드와 대조해 추린, **모르고 짜면 반드시 한 번 막히는 지점**들이다.

### 3.1 응답 언랩

모든 REST 응답이 `{ success, data, message }`로 한 겹 감싸져 있다. `data`만 꺼내 쓰되 **`success=false`면 `message`를 그대로 사용자에게 보여준다.**

```dart
// core/api/api_response.dart 요지
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
}
```

### 3.2 ⚠️ 에러 코드 필드가 없다

실패 응답에 `errorCode` 같은 **기계판독용 필드가 없다.** 분기 근거는 **HTTP status 뿐**이고, `message`는 사람에게 보여주는 용도다.
→ `ApiException`을 `status` 기준으로만 만든다. 절대 `message` 문자열을 파싱해서 분기하지 말 것.

| status | 앱 처리 |
|---|---|
| 400 | 폼 검증 오류 — `message`를 필드 하단에 표시. **여러 필드가 틀려도 1개만 온다** → 재제출 후 또 다른 오류가 나올 수 있음을 감안 |
| 401 | 토큰 refresh 시도 → 실패 시 로그인 화면으로 |
| 403 | "권한 없음" 표시. 역할 자체 불일치 / 담당 아님 두 경우가 같은 403이라 구분 불가 |
| 404 | "대상 없음" 빈 상태 표시 |
| 409 | 이미 처리된 요청 — 버튼 재활성화하지 말고 목록 새로고침 |
| 500 | 공통 에러 배너 |

### 3.3 ⚠️ accessToken이 15분마다 만료된다

- accessToken **900초(15분)** / refreshToken **14일**
- `POST /api/auth/refresh` 응답은 **accessToken과 refreshToken을 둘 다 새로 준다**(refresh 토큰 회전) → 둘 다 저장 갱신 필요
- **401 수신 시 자동 refresh 후 원 요청 1회 재시도**를 `auth_interceptor.dart`에 구현한다
- 동시 요청 여러 개가 한꺼번에 401을 받으면 refresh가 중복 호출된다 → **refresh는 뮤텍스로 1회만 태우고 나머지는 대기시킨다**

### 3.4 ⚠️ 로그인 응답에 사용자 정보가 없다 — JWT를 직접 디코딩해야 한다

로그인 응답은 `{ accessToken, refreshToken }` 뿐이고, **`/api/users/me` 같은 엔드포인트가 없다.**
역할·userId·tenantId는 **accessToken(JWT) payload에서 꺼낸다** (`JwtTokenProvider` 대조 확인, 2026-07-28):

| 클레임 | 내용 |
|---|---|
| `sub` | userId |
| `email` | 이메일 |
| `memberships` | `"tenantId:ROLE"` 문자열 배열 (예: `["1:ACADEMY_ADMIN"]`) |
| `type` | `access` / `refresh` |

→ `features/auth/`에서 payload를 Base64URL 디코딩해 `AuthSession { userId, email, role, tenantId }`를 만든다.

⚠️ `memberships` 원소는 `"tenantId:ROLE"` 형식인데, **`PLATFORM_ADMIN`은 소속 학원이 없어 tenantId 자리가 빈 문자열**로 온다
(`":PLATFORM_ADMIN"`). `split(':')[0]`을 그대로 `int.parse`하면 터진다 → 빈 문자열이면 `null`로 다룰 것.

> 서명 검증은 클라이언트가 할 필요 없다(서버가 매 요청 검증한다). 클라이언트는 **화면 분기용으로만** 읽는다.

### 3.5 기사 `busId` 조회 — 백엔드에 `GET /api/buses/me` 신설 (D1 확정, 2026-07-28)

기사용 API는 전부 `busId`를 입력으로 받는데(`GET /api/route-plans/driver/{busId}`, `POST /api/locations/bus`,
`GET /api/ride-events/bus/{busId}`, `POST /api/drive-sessions/start`), **DRIVER가 자기 담당 busId를 조회할 엔드포인트가 없었다.**
`GET /api/buses`는 관리자 전용이고 JWT 클레임에도 busId가 없다.

→ **백엔드에 `GET /api/buses/me`(권한 `DRIVER`)를 추가**해 해결한다(사용자 확정). 작업 항목은 **C0**(§6).

- 응답: 기존 `BusResponse`(담당 버스 1대). 담당 버스가 없으면 `404 NOT_FOUND`
- 프론트는 로그인 직후 1회 호출해 `busId`를 세션에 캐시하고, 이후 기사 화면 전체에서 재사용한다
- MVP API 17개에는 없던 엔드포인트다 — 추가 후 `MVP_API_SPEC.md`·Swagger `"00. MVP 사용 API"` 태그도 함께 갱신할 것(17→18)

### 3.6 ⚠️ 버스 위치는 WebSocket으로 안 온다 — 폴링해야 한다

WebSocket 구독 목록에 **버스 위치가 없다.** `/user/queue/location`·`/topic/tenant/{id}/location`은 전부 **학생** 위치다.

- 관리자 관제 지도는 `GET /api/locations/buses`를 **3,000ms 주기로 직접 폴링**한다(서버 위치 갱신 주기가 3초라 더 자주 불러도 새 값이 없다)
- 화면이 백그라운드로 가면 폴링을 멈춘다(타이머 누수 방지)
- **위치 보고가 한 번도 없는 버스는 응답 배열에서 아예 빠진다** → "버스 없음"과 "위치 없음"을 구분할 수 없다.
  버스 목록이 필요하면 `GET /api/buses`를 별도로 불러 합쳐야 한다

### 3.7 WebSocket(STOMP) 규약

- endpoint `ws://<host>/ws/location`, **SockJS 미사용**
- 인증: `CONNECT` 프레임의 네이티브 헤더 `Authorization: Bearer <accessToken>` — **세션 수립 시 1회만** 검증
- **재연결은 100% 클라이언트 책임**. `stomp_dart_client`의 `reconnectDelay`를 쓰되, **재연결 때마다 헤더를 다시 실어야 한다**
  (이전 세션 인증은 재사용 안 됨). 이때 토큰이 만료됐으면 refresh 먼저 → 그 다음 CONNECT
- heartbeat 10초
- **⚠️ WS는 "연결 이후의 변화"만 준다.** 초기 화면은 **반드시 REST로 먼저 채우고**, 그 뒤 도착분만 덧붙인다
- `/topic/tenant/{tenantId}/**` 구독은 추가 인가 검사가 있다(그 학원 관리자 또는 PLATFORM_ADMIN만) → 기사 앱은 `/user/queue/**`만 구독

| destination | 구독 주체 |
|---|---|
| `/user/queue/notifications` | 기사(자기 반 학생 관련 알림) |
| `/topic/tenant/{tenantId}/notifications` | 관리자 |

### 3.8 ⚠️ polyline 좌표 순서가 `[경도, 위도]`다

`RoutePlanResponse.polyline`은 **JSON 배열이 아니라 JSON 문자열**로 온다: `"[[127.0275,37.501],...]"`

1. 먼저 `jsonDecode`로 문자열을 한 번 더 파싱한다
2. **각 원소는 `[lng, lat]` 순서**다. `flutter_map`의 `LatLng(lat, lng)`와 **순서가 반대**이므로 뒤집어 넣어야 한다.
   안 뒤집으면 노선이 지도 밖(바다 한가운데)에 그려진다

### 3.9 CORS

`localhost:3000`은 백엔드 `app.cors.allowed-origins` 기본값에 **이미 포함**돼 있다 → Docker 프론트를 3000 포트로 띄우면 설정 변경 불필요.
다른 포트를 쓰면 `CORS_ALLOWED_ORIGINS` 환경변수로 추가해야 한다. `http://localhost:3000`과 `http://127.0.0.1:3000`은 **다른 출처**로 취급된다.

### 3.10 API Base URL

빌드 시점 주입: `--dart-define=API_BASE_URL=http://localhost:8080`
→ `const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080')`

**브라우저에서 실행되므로 `localhost:8080`이 맞다**(컨테이너 이름 `backend:8080`이 아니다 — 요청 주체가 컨테이너가 아니라 사용자 브라우저다).

---

## 4. 화면 ↔ API 매핑

### 4.1 공통

| 화면 | API |
|---|---|
| 로그인 | `POST /api/auth/login` |
| (백그라운드) 토큰 갱신 | `POST /api/auth/refresh` |

로그인 성공 → JWT 디코딩(§3.4) → 역할에 따라 `/driver` 또는 `/admin`으로 리다이렉트.

#### 빠른 로그인 (기능 테스트용, 사용자 요청 2026-07-28)

로그인 화면 하단에 **시드 계정 원터치 버튼**을 둔다(`QuickLoginPanel`).

- **인증을 우회하지 않는다** — 시드 계정으로 *정상 로그인*을 대신 눌러줄 뿐이다.
  토큰 없이 들어가면 모든 API가 401이라 우회는 애초에 쓸모가 없다
- 노출 여부는 **빌드 플래그** `ENABLE_QUICK_LOGIN`(기본 **false**)이 정한다.
  `docker-compose.yml`의 frontend build args에서만 `true` — **운영 이미지 빌드 시 이 줄을 빼면 된다**
- 검증: 플래그 OFF 빌드에는 시드 계정 문자열이 **0회**(트리 셰이킹으로 제거), ON 빌드에는 1회

⚠️ **선탑자(동승보호자) 전용 버튼은 만들 수 없다.** `Role` enum에 그 역할이 없고 `DRIVER`로 흡수하기로
확정돼 있다(`MVP_RELEASE_TRACKER.md` §0, `PROJECT_MASTER_PLAN.md` §12.1). 기사 버튼 하나가 두 역할을 겸한다.
시드에도 기사 계정은 **1개뿐**이다(3호차 담당 박기사. 1호차는 기사 미배차).

### 4.2 기사 (DRIVER) — 모바일 레이아웃

| 화면 | API | 비고 |
|---|---|---|
| 오늘의 노선 | `GET /api/route-plans/driver/{busId}?serviceDate=` | PUBLISHED만 내려온다. 등원/하원 탭 분리 |
| 노선 지도 | (위 응답의 `polyline`·`stops`) | §3.8 좌표 순서 주의 |
| 승하차 기록 | `POST /api/ride-events` | `BOARD`/`ALIGHT`/`HANDOVER` 버튼. `source`는 서버가 `MANUAL`로 채움 |
| 오늘 명단 | `GET /api/ride-events/bus/{busId}?date=` | 기록 후 재조회로 목록 갱신 |
| 위치 보고 | `POST /api/locations/bus` | 주기 전송. §8 D2 참조 |
| 알림 | WS `/user/queue/notifications` | `ROUTE_PUBLISHED` 수신 시 노선 재조회 |

### 4.3 관리자 (ACADEMY_ADMIN / PLATFORM_ADMIN) — 데스크톱 레이아웃

| 화면 | API | 비고 |
|---|---|---|
| 관제 지도 | `GET /api/locations/buses?tenantId=` | **3초 폴링**(§3.6) |
| 배차 제안 | `POST /api/route-plans/auto-assign` | 응답의 `excludedStudentNames`를 **경고 배너로 반드시 표시**(에러 아님, 좌표 없어 제외된 학생) |
| 배차 확정 | `POST /api/route-plans/auto-assign/confirm` | `planIds` 전달. 제안→확정 사이 화면에서 검토. **409면 이미 확정된 것** → 목록 새로고침 |
| 노선 목록 | `GET /api/route-plans?tenantId=&busId=` | |
| 노선 상세 | `GET /api/route-plans/{id}` | 정차 순서 + 지도 |
| 알림 이력 | `GET /api/notifications?tenantId=` + WS `/topic/tenant/{id}/notifications` | REST로 초기 로드 후 WS 덧붙이기(§3.7) |

`PLATFORM_ADMIN`은 `tenantId`가 **필수**다(생략 시 400). `ACADEMY_ADMIN`은 생략하면 본인 학원.
→ 플랫폼 관리자로 로그인하면 **학원 선택 UI가 먼저 필요**하다. MVP에서는 시드 기준 `tenantId=1` 고정으로 두고 §8 D3에서 확정.

**`approve`/`publish`(§5.3·5.4)는 화면에 넣지 않는다** — `confirm`이 승인·배포까지 한 번에 처리하므로 MVP에서 직접 호출할 일이 없다.

---

## 5. Docker 구성 — nginx 리버스 프록시 단일 진입점

> **모든 HTTP 접근은 `:80`의 nginx 프록시 한 곳을 지난다.** backend·frontend는 호스트에 포트를 열지 않는다.
> (사용자 확정 2026-07-28. 기획서 목표 스택의 "Nginx 리버스 프록시" 항목에 해당)

```
브라우저
   │
   ▼  :80
┌──────────────────── proxy (nginx:alpine) ────────────────────┐
│  /                → frontend_pool  (Flutter Web 정적)         │
│  /api/            → backend_pool                              │
│  /ws/             → backend_pool   (Upgrade 헤더 처리)        │
│  /swagger-ui·/v3/api-docs → backend_pool                      │
└───────────────────────────────────────────────────────────────┘
     │                                  │
     ▼ frontend:80                      ▼ backend:8080
  nginx(정적 서빙 + SPA fallback)     Spring Boot
```

설정 파일: **`infra/proxy/nginx.conf`** (볼륨 마운트 — 고친 뒤 `docker compose restart proxy` 면 반영, 재빌드 불필요)

| 주소 | 용도 |
|---|---|
| `http://localhost/` | 화면 |
| `http://localhost/api/...` | API |
| `ws://localhost/ws/location` | STOMP WebSocket |
| `http://localhost/swagger-ui/index.html` | Swagger UI |

DB/Redis/Kafka 포트(5432·6379·29092)만 호스트에 남겼다 — DB 툴 접속과, 인프라만 컨테이너로 띄우고 백엔드는 IDE에서 `bootRun` 하는 개발 방식을 위해서다.

### 5.1 프록시가 생기면서 달라진 것 ★

**CORS가 사라졌다.** 프론트와 API가 같은 출처(`:80`)가 되므로 브라우저가 preflight를 보내지 않는다.
→ `API_BASE_URL`을 **빈 문자열**로 빌드하고 dio가 상대 경로(`/api/...`)로 요청한다.
같은 번들이 `localhost`에서도 배포 도메인에서도 그대로 동작하고, 출처 목록 관리도 필요 없어진다.

⚠️ **WebSocket은 상대 경로를 못 쓴다.** 반드시 `ws://host:port/...` 절대 주소여야 해서,
`ApiConfig.wsUrl`이 `apiBaseUrl`이 비면 **현재 페이지 주소(`Uri.base`)에서 유도**한다. https면 자동으로 `wss`.

### 5.2 ⚠️ nginx 상속 함정 (실제로 겪음)

한 `location` 안에서 `proxy_set_header`를 **하나라도** 쓰면 **server 레벨의 `proxy_set_header`가 전부 상속되지 않는다.**
`/ws/` 블록에 Upgrade/Connection만 적었더니 `Host`가 업스트림 이름(`backend_pool`)으로 나가 핸드셰이크가 **400**으로 거절됐다.
→ 공통 헤더를 각 location에 다시 적어야 한다.

### 5.3 Dockerfile / 정적 서빙

- `frontend/Dockerfile` — 멀티스테이지(`ghcr.io/cirruslabs/flutter:stable` → `nginx:alpine`), `API_BASE_URL` build-arg
- `frontend/nginx.conf` — SPA fallback(`try_files … /index.html`) + `index.html` `no-store` / 해시 산출물 장기 캐시
- ⚠️ **프록시에는 `try_files`를 쓰지 않는다** — 프록시엔 파일이 없어 전부 404가 된다. SPA fallback은 frontend 컨테이너가 담당

> 프론트 UI를 반복 수정할 땐 컨테이너 재빌드가 느리다:
> `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080`
> (이땐 프록시를 안 거치므로 백엔드를 8080으로 따로 띄우고 CORS 허용 목록을 쓴다)

## 6. 작업 백로그 (커밋 단위 체크리스트)

> **상태 범례**: ⬜ 미착수 / 🟡 진행중 / ✅ 완료 / ⛔ 블록
> 각 항목 완료 시 **검증 결과와 커밋 해시를 병기**한다. 한 항목 = 한 커밋을 원칙으로 한다
> (세션이 중간에 끊겨도 커밋된 지점까지는 안전하게 남기기 위함).

### P0 — 스캐폴딩

- [x] ✅ **C0** *(백엔드)* `GET /api/buses/me` 신설 — 권한 `DRIVER`, 담당 버스 1대 반환(§3.5)
  - `BusController.myBus()` (메서드 레벨 `@PreAuthorize("hasRole('DRIVER')")`로 클래스 레벨 관리자 전용 규칙을 덮어씀)
    + `BusQueryService.getMyBus()` + `BusRepository.findByDriverIdOrderByIdAsc()`
  - Swagger `"00. MVP 사용 API"` 이중 태깅 + `MVP_API_SPEC.md` §2.3 신설(17→18)
  - **검증 완료(2026-07-28, Docker 기동 상태)**:
    - `./gradlew test` **100/100 통과** (신규 3케이스: 정상·담당버스없음 404·복수버스 시 첫 건)
    - 실호출 `GET /api/buses/me` — `driver@school.com` → `{id:1, name:"3호차", driverId:3, driverName:"박기사", onboard:3}`
    - 권한 경계: ADMIN→403 · STUDENT→403 · 미인증→401 · `GET /api/buses`(관리자)는 여전히 200
      → 메서드 레벨 `@PreAuthorize`가 클래스 레벨을 의도대로 덮어쓰고, 기존 관리자 API는 영향 없음
    - Swagger `"00. MVP 사용 API"` 그룹 `/v3/api-docs` 실측 **18개**(`/api/buses/me` 포함) — 명세서와 일치
- [x] ✅ **C1** Flutter 프로젝트 생성 + 의존성 + 폴더 골격 + **코드 컨벤션 문서**
  - Flutter 3.44.8 / `school_bus` / `--platforms=web,android,ios --empty`
  - `FLUTTER_CODE_CONVENTIONS.md` 신설 — 계층·Port·DTO 규칙 + 에이전트용 검사 체크리스트(§9)
  - `lib/` 구조: `main.dart`(1줄) → `bootstrap.dart`(초기화·전역 에러핸들러) → `app/app.dart`(셸)
    + `app/theme/`(`AppTheme`·`AppSpacing`·`AppBreakpoints`) + `core/api/api_config.dart`
  - ⚠️ **`riverpod_annotation`/`riverpod_generator` 제외** — Flutter 3.44.8 번들 analyzer와 버전 충돌.
    Provider는 손으로 선언한다(입문 단계엔 오히려 마법이 적어 유리). 코드생성은 freezed/json_serializable만
  - **검증**: `flutter analyze` 무경고 · `dart format` 적용 · `flutter build web --release` 성공(`main.dart.js` 2.1MB)
- [x] ✅ **C2** `Dockerfile` + `nginx.conf` + `docker-compose.yml` frontend 서비스(§5)
  - `profiles` 제거해 기본 `docker compose up`에 포함, 포트 `"3000:80"`, `API_BASE_URL`을 build-arg로 전달
  - ⚠️ **`ghcr.io/cirruslabs/flutter`에는 버전 태그가 없다**(`stable`/`beta`/`latest`뿐) — 이미지 고정 불가.
    stable 이미지 Dart가 3.12.0인데 `flutter create` 기본 제약이 `^3.12.2`라 `pub get`이 실패했다
    → **pubspec의 `environment.sdk`를 `^3.12.0`으로 낮춰** 흡수(상한 `<4.0.0`은 그대로라 안전).
    로컬에서만 되는 최신 문법을 쓰면 여기서 깨지므로 **빌드 확인은 항상 컨테이너로** 할 것
  - **검증 완료**: `/` 200(1,508B) · 딥링크 `/admin/routes` **200**(SPA fallback 동작, 404 아님) ·
    `main.dart.js` 200(2.2MB, gzip 779KB, `max-age=2592000 immutable`) · `index.html` `no-store` ·
    번들에 `http://localhost:8080` 주입 확인 · 컨테이너 5개 기동

### P1 — 코어 인프라

- [x] ✅ **C3** `ApiResponse<T>` 언랩 + dio 클라이언트 + `ApiException`(HTTP status 매핑, §3.1~3.2)
  - `core/api/`: `api_response.dart`(봉투 + `Decode.one/list/unit` 디코더) · `api_exception.dart`(`ApiErrorKind` 8갈래)
    · `api_client.dart`(dio 캡슐화, 봉투 해제, 예외 통일, null 쿼리 제거) · `interceptor/logging_interceptor.dart`
  - **dio 는 `ApiClient` 밖으로 나가지 않는다** — 밖으로는 `ApiException`만 나간다(컨벤션 C-1 자동 충족)
  - 설계 포인트: ① HTTP 200 + `success:false` 도 예외로 처리(계약 변경 시 조용히 통과 방지)
    ② `?date=null` 로 400 나는 사고를 막는 쿼리 정리 ③ 로깅은 debug 빌드만, Authorization 은 존재 여부만 기록
  - **검증**: `flutter test` **13/13 통과**(봉투 해제 5 · status 매핑 4 · 네트워크 2 · 쿼리 정리 2), `flutter analyze` 무경고
- [x] ✅ **C4** 로그인 화면 + 토큰 저장 + JWT 디코딩(§3.4) + 401 자동 refresh 인터셉터(뮤텍스 포함, §3.3)
  - `core/storage/{spec,impl}` — `TokenStorage` 포트 + `SecureTokenStorage`
  - `core/api/interceptor/auth_interceptor.dart` — Bearer 부착, 401 → 재발급 → **1회만** 재시도
  - `features/auth/` — `JwtDecoder`(memberships 파싱) · `AuthRepository` · `AuthController` · `LoginScreen`
  - `shared/domain/` — `Role`(MVP 지원 여부 포함) · `AuthSession`
  - ⭐ **DIP 적용**: `core`가 `features`를 import하면 컨벤션 C-1 위반이라, core에 `SessionRefresher` **포트**를 두고
    구현(`AuthSessionRefresher`)은 `bootstrap()`에서 provider override로 주입한다 — `bootstrap.dart`가 합성 지점
  - ⚠️ **재시도용 Dio는 주입 가능하게** 뒀다. 별도 인스턴스로 고정하면 테스트의 가짜 어댑터를 못 타고 실제 네트워크로 나간다
  - **검증**: `flutter test` **30/30 통과** — 그중 핵심 2건:
    ① *동시에 401을 받아도 재발급은 1회만*(폴링+알림이 같이 만료되는 상황) ② *재시도가 또 401이어도 무한 반복 안 함*
    JWT: `":PLATFORM_ADMIN"`(tenantId 빈 문자열) · 복수 멤버십 · 알 수 없는 역할 · base64 padding 전부 커버
  - **실환경 검증**: CORS preflight에서 `Authorization` 헤더 허용 확인, `Origin: localhost:3000`으로 로그인 200
- [x] ✅ **C5** `go_router` + 역할별 redirect 가드 + 반응형 셸
  - `app/router/`: `app_routes.dart`(경로 상수) · `role_redirect.dart`(**순수 함수** 가드) · `app_router.dart`
  - `app/shell/app_shell.dart` — 폭에 따라 `NavigationRail`(넓음) / `NavigationBar`(좁음) 전환, `AppBreakpoints.compact` 기준
  - `StatefulShellRoute.indexedStack` — 탭을 옮겨도 각 탭의 스크롤·입력이 유지된다
  - 자리표시자 화면 6개 생성(`PendingScreen`) — 각 화면에 **어느 C 항목에서 채워지는지** 표시.
    C6~C13 에이전트가 채울 슬롯이다
  - ⭐ 가드를 위젯이 아니라 **순수 함수**로 뺐다 — 화면에 흩어지면 전체 규칙을 아무도 못 보고, 테스트도 못 한다
  - **검증**: `flutter test` **43/43**(가드 12케이스: 복원중·미로그인·기사·관리자·MVP밖 역할 교차 접근).
    컨테이너 배포 후 딥링크 9개 전부 200(`/admin/routes/1` 포함)
  - 화면 트리: 기사 = 오늘의노선·승하차명단 / 관리자 = 관제지도·배차·노선·알림

### P2 — 기사 앱  *(C0 완료 후 착수)*

- [x] ✅ **C6** 오늘의 노선 화면 + 지도(polyline·정차 마커) + `MapViewAdapter` 포트
  - `core/map/{spec,impl}` — `MapViewAdapter` 포트(중립 `GeoPoint`) + `FlutterMapAdapter`(OSM).
    **지도 라이브러리를 아는 파일은 impl 하나뿐** → C9·C11도 이 포트만 쓴다
  - `features/routing/` — `RoutePlanDto`(서버 표현) / `RoutePlan`(도메인, **polyline 파싱**) / repository / controller / 화면
  - 로그인 직후 `GET /api/buses/me`로 busId를 세션에 캐시(§3.5) — auth 에 둔 이유는 세션 부트스트랩이라서(feature 간 의존 회피)
  - 빈 상태를 **둘로 나눔**: "배차된 버스 없음"(관리자에게 요청) vs "배포된 노선 없음"(기다리면 됨) — 기사가 할 행동이 다르다
  - **검증**: `flutter test` **53/53**(polyline 좌표 역순·깨진 JSON·시드 응답 변환·거리/시간/ETA 표기).
    실 백엔드 E2E — 배차 제안 → 확정(PUBLISHED) → `GET /api/route-plans/driver/1` 로 **정차 3곳·polyline 172점** 수신 확인
  - ⚠️ **인프라 결함 발견·수정**: compose 가 `backend/.env` 를 로드하지 않아 NCP 네이버 Directions 키가 컨테이너에 없었다.
    배차 API 가 **401 → "서버 오류"** 로만 보였다. `env_file`(`required: false`) 추가로 해결
- [ ] ⬜ **C7** 승하차 기록(`POST /api/ride-events`) + 오늘 명단 조회
- [ ] ⬜ **C8** 버스 위치 주기 보고(`POST /api/locations/bus`) — **Mock / 실GPS 토글**(§8 D2)
  - `LocationSource` 추상 + `MockLocationSource`(노선 polyline 따라 이동) / `GpsLocationSource`(`geolocator`)
  - 기사 화면 상단에 토글 스위치, 기본값 **Mock**. 5,000ms 주기 전송

### P3 — 관리자 콘솔

- [ ] ⬜ **C9** 관제 지도 + 3초 폴링(§3.6) — 라이프사이클 연동 타이머 정리 포함
- [ ] ⬜ **C10** 배차 제안 → 검토 → 확정 흐름(`excludedStudentNames` 경고 배너 포함)
- [ ] ⬜ **C11** 노선 목록 / 상세

### P4 — 실시간

- [ ] ⬜ **C12** STOMP 연결·구독·재연결(§3.7) — 재연결 시 토큰 재주입
- [ ] ⬜ **C13** 알림함: REST 초기 로드 + WS 덧붙이기(기사=`/user/queue`, 관리자=`/topic/tenant/{id}`)
  - 검증: 기사가 승하차 기록 → 관리자 화면에 알림이 즉시 뜨는지(2개 브라우저 창)

### P5 — 마감

- [ ] ⬜ **C14** 로딩/빈상태/에러 UI 통일 + 전체 시나리오 통합 점검
  - 검증: `docker compose down && up` 후 시드 상태에서 기사·관리자 전 화면 1회씩 통과

---

## 7. 세션 재개 지점

> ⚠️ **작업 규칙 (사용자 요청, 2026-07-28): 토큰 소진으로 세션이 중간에 끊길 것을 전제로 진행한다.**
> **한 항목(C*)을 끝낼 때마다 §6 체크박스와 이 절을 갱신하고 커밋한다.** 다음 세션은 이 문서만 읽고 이어간다.
> 항목을 마치지 않은 채 다음으로 넘어가지 않는다.

- **마지막 완료 항목**: **C5** — 라우팅·역할가드·반응형 셸 완료. **코어(C0~C5) 전부 끝. `flutter test` 43/43**
- **다음 할 일**: **C6** — 기사 오늘의 노선. 로그인 직후 `GET /api/buses/me`로 busId 캐시(§3.5) →
  `GET /api/route-plans/driver/{busId}` → `MapViewAdapter` 포트 + `FlutterMapAdapter`로 polyline·정차 마커(§3.8 좌표 역순 주의)
- **그 다음**: C7·C8(기사) → C9~C11(관리자) → C12·C13(실시간) → C14(마감)
- **에이전트 투입 방식**(사용자 요청): C6~C11은 feature 단위로 병렬 가능.
  각 에이전트에 ① 담당 자리표시자 화면 경로 ② `FLUTTER_CODE_CONVENTIONS.md` 준수 ③ 이 문서 §3 함정 목록을 전달하고,
  완료 후 `convention-auditor`로 컨벤션 §9 체크리스트 검사를 돌린다.
  ⚠️ `core/map`(`MapViewAdapter`)은 C6·C9·C11이 함께 쓰므로 **C6에서 먼저 만든 뒤** 나머지를 병렬로 돌린다
- **브라우저 확인**: `http://localhost/` → 로그인 → 역할별 화면(기사 2탭 / 관리자 4탭)
  - `driver@school.com` · `admin@school.com` · `platform@school.com` / 비밀번호 전부 `password`
  - `student@school.com`으로 로그인하면 "준비 중" 안내(MVP 범위 밖)
- **인프라 상태**: postgres(healthy)·redis·kafka·backend 4개 기동 중.
  꺼졌다면 §9의 PATH를 잡고 `docker compose up -d --build`(볼륨이 없어 `down` 후 `up`이면 시드 상태로 리셋된다)
- **에이전트 활용**: 화면 작업(C6~C11)은 feature 단위로 병렬화 가능 — 에이전트에 `FLUTTER_CODE_CONVENTIONS.md` 준수를 명시하고,
  완료 후 `convention-auditor`로 §9 체크리스트 검사를 돌린다(사용자 요청, 2026-07-28)
- **환경 메모**: Docker(postgres/redis/kafka/backend)는 **사용자가 직접 켠다** — 필요할 때 요청할 것

---

## 8. 설계 결정 기록 (확정됨)

> 다음 세션에서 **같은 논의를 반복하지 않기 위한 기록**이다. 뒤집을 땐 여기부터 고친다.

### D1. 기사 `busId` 조회 → **백엔드에 `GET /api/buses/me` 신설** ✅ 확정 2026-07-28

기사용 API가 전부 `busId`를 입력으로 받는데 DRIVER가 그걸 조회할 수단이 없었다(§3.5).
하드코딩(`busId=1`)·수동입력 대안은 기사 계정이 2명 이상이면 즉시 깨지므로 배제.
**MVP 범위 확장이 아니라 MVP를 동작시키기 위한 최소 보완**으로 판단해 백엔드 엔드포인트 1개를 추가한다 → **C0**.

### D2. 위치 보고 좌표 출처 → **Mock / 실GPS 토글 스위치** ✅ 확정 2026-07-28

`LocationSource` 추상 뒤에 두 구현체를 두고 기사 화면에서 토글한다 — 백엔드의 `LocationSource` 포트 패턴과 대칭.

- `MockLocationSource` — **기본값**. 조회한 노선 polyline을 따라 좌표를 보간해 이동시킨다. 브라우저에서 위치 권한·개인정보 동의 없이 전 흐름 시연 가능
- `GpsLocationSource` — `geolocator`로 실제 단말 좌표. 모바일 실기기 확인용
- 전송 주기 **5,000ms** (서버 위치 갱신 3초 / 관제 지도 폴링 3초와 균형)

> 이 토글이 `PROJECT_MASTER_PLAN.md` Phase 8(Mock→실 GPS 전환)의 프론트 쪽 준비물이 된다.

### D3. `PLATFORM_ADMIN` 학원 선택 → **`tenantId=1` 고정** ✅ 기본값 채택 2026-07-28

플랫폼 관리자는 `tenantId`가 필수인데 소속 학원이 없다(§4.3). 학원 목록 API(`/api/tenants`)는 MVP 17개 밖이므로
MVP에서는 시드 기준 `tenantId=1`로 고정하고 화면 상단에 "고정값" 표시만 한다. 학원 선택 드롭다운은 MVP 이후.

### D4. 지도 = `flutter_map`(OSM) ✅ / D5. Docker 대상 = Flutter Web ✅

각각 §1.3·§1.2에 근거 기록.

---

## 9. 리스크 / 전제

### 🔧 로컬 환경 — Docker CLI가 PATH에 없다 (2026-07-28 확인)

**Docker Desktop은 `/Applications/Code/Docker.app`에 설치돼 있다**(사용자가 `/Applications`를 용도별 폴더로 정리해서 쓴다).
그런데 `/usr/local/bin/docker`는 옛 경로 `/Applications/Docker.app/...`을 가리키는 **끊어진 심볼릭 링크**라
`which docker`가 실패한다 — "Docker 미설치"로 오판하기 쉽다.

**셸에서 docker를 쓰려면 PATH를 먼저 잡는다:**

```bash
export PATH="/Applications/Code/Docker.app/Contents/Resources/bin:$PATH"
docker compose up -d --build      # Docker 29.4.1 / Compose v5.1.3 확인됨
```

> `find`로 앱을 찾을 때 주의 — 이 환경의 셸은 rtk 프록시를 거치면서 **`find` 출력이 뭉개진다**
> (`0 for '*docker*'`처럼 잘못된 요약이 나온다). 파일 존재 확인은 `ls`나 `rtk proxy find`를 쓸 것.

### ⛔ C1 블로커 — Flutter SDK 미설치

전역 검색 결과 SDK가 없다(`~/.oh-my-zsh/plugins/flutter`는 zsh 자동완성 플러그인이지 SDK가 아니다).

```bash
brew install --cask flutter
flutter doctor                     # Chrome 항목이 ✓ 여야 Web 빌드 가능
```

### 기타

- **Docker 인프라는 사용자가 직접 켠다** — 백엔드·DB가 안 떠 있어 생긴 실패는 코드 결함이 아니라 **환경 문제**로 분류해 보고한다(루트 `CLAUDE.md` 작업 규칙)
- **로컬 postgres에 영속 볼륨이 없다** — `docker compose down` 후 `up`이면 데이터가 시드로 리셋된다. 프론트 테스트로 꼬인 데이터는 이 방법으로 되돌린다
- **Swagger UI가 항상 최신** — 이 문서와 `MVP_API_SPEC.md`가 어긋나면 `http://localhost:8080/swagger-ui/index.html`의 "00. MVP 사용 API" 그룹이 기준이다
- **백엔드 API가 바뀌면 이 문서 §3·§4도 같이 갱신**한다
- 패키지 버전은 명시하지 않는다 — `flutter pub add` 시점의 최신 안정판을 쓰고, 확정된 버전은 `pubspec.lock`이 기록한다

---

## 10. ⚠️ 로드밸런싱 — 지금 붙이면 깨진다 (2026-07-28 조사)

프록시(§5)의 `upstream backend_pool` 에 서버를 추가하면 문법상으로는 바로 다중화된다.
**하지만 백엔드가 아직 다중 인스턴스를 감당하지 못한다.** 실제 코드를 확인해 찾은 블로커 3건:

| # | 블로커 | 증상 | 해결 방향 |
|---|---|---|---|
| **L1** | `@Scheduled` **4개**가 인스턴스마다 실행<br>(`LocationSimulationScheduler` 3s · `ConnectionLossScheduler` 10s · `ApproachNoShowScheduler` 15s · `SosEscalationScheduler` 30s) | **알림이 인스턴스 수만큼 중복 발송.** 근접·미승차·SOS 에스컬레이션이 2대면 2번, 3대면 3번 | ShedLock 등 분산 락, 또는 스케줄러 전용 인스턴스 분리 |
| **L2** | 위치 저장소가 **인메모리**<br>(`InMemoryBusLocationRepository` = `ConcurrentHashMap`) | 기사가 A 인스턴스에 보고한 좌표를 관리자가 B 인스턴스에서 조회하면 **안 보인다**. 관제 지도가 3초마다 깜빡임 | Redis 구현체로 교체 — 이미 `BusLocationRepository` 포트가 있어 **구현체만 추가**하면 된다(호출부 수정 불필요) |
| **L3** | WebSocket 세션이 인스턴스에 묶임<br>(`LocationSessionRegistry` 인메모리) | 연결 끊김 감지 오작동, 특정 사용자에게 push가 안 감 | 최소: `ip_hash` 세션 어피니티 / 제대로: Redis STOMP 브로커 릴레이 |

> **L2가 가장 저렴하다.** 백엔드가 이미 `LocationSource`/`BusLocationRepository`를 포트로 분리해 뒀기 때문에
> (`backend/docs/reference.md` §15) Redis 구현체를 추가하고 빈만 바꾸면 된다. Redis 컨테이너도 이미 떠 있다.

**현재 판단**: 이 3건은 **백엔드 작업이고 MVP 범위 밖**이다(트래커 §0의 MVP 5개 기능에 없음).
프론트 MVP(C5~C14)를 먼저 끝내고, 로드밸런싱이 실제로 필요해지는 시점에 별도 항목으로 다룬다.
프록시 설정에는 확장 지점(`upstream` + `least_conn`)과 이 경고를 주석으로 남겨뒀다(`infra/proxy/nginx.conf`).
