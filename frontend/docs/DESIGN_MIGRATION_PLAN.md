# 디자인 이식 작업 추적 (D0~D9)

> **문서 성격**: Claude Design 시안을 Flutter 코드로 옮기는 작업의 **진행 추적**. 무엇이 끝났고 다음이 무엇인지만 적는다.
> 규칙 자체는 `DESIGN_SYSTEM.md`, 코드 규약은 `FLUTTER_CODE_CONVENTIONS.md`, 기능 계획은 `FLUTTER_FRONTEND_PLAN.md`.
>
> ⚠️ **토큰 소진으로 세션이 끊길 것을 전제로 진행한다.** 한 항목(D*) = 한 커밋. 커밋 직후 이 문서를 갱신한다.
> 다음 세션은 이 문서만 읽고 §세션 재개 지점부터 이어간다.
>
> 시작일 2026-07-29

---

## 배경

`lib/` 는 기능 구현이 이미 끝나 있다(`FLUTTER_FRONTEND_PLAN.md` §6, C0~C13 완료). 없는 건 **시각 언어**였다 — 테마 자산이 `app_theme.dart`(시드 1개) + `app_spacing.dart` 둘뿐이라 화면마다 M3 기본값에 기대 그려져 있었고, 지시서가 요구한 운전석 조건(직사광선 대비·탭 1회·색만으로 상태 구분 금지)이 코드로 강제되지 않았다.

**이 작업은 순수 표현 계층 교체다.** 로직·API 호출·provider·라우팅을 바꾸지 않는다.

**사용자 확정(2026-07-29)**: 범위 = 기사 + 관리자 전체 11화면 / 문서 = Markdown SoT / 에이전트 = 생성·검사 2개 신설 / 화면 이식은 에이전트 팀 병렬

---

## 체크리스트

> 범례: ⬜ 미착수 / 🟡 진행중 / ✅ 완료 / ⛔ 블록

- [x] ✅ **D0** 디자인 원본 반입 — `docs/design/source/` (커밋 `a415263`)
  - `통학버스 디자인 시스템.dc.html`(51KB) · `기사앱 MVP.dc.html`(71KB) · `support.js`(dc-runtime) + `README.md`
  - `android-frame.jsx` 는 **의도적으로 제외** — 파일 스스로 `@ds-adherence-ignore` 스타터라고 밝히고 팔레트가 Material 샘플(`#006a60`)이라 우리 브랜드와 무관. 대응물은 `AppShell.forceCompact` 로 이미 존재
  - 반입 방법(재현용): `DesignSync(method="get_file", projectId="b979a5b1-223c-439b-91ef-e9f7c4f54b9b", path=…)`
- [x] ✅ **D1** `DESIGN_SYSTEM.md` + 이 문서 신설
  - 시안의 CSS 변수 → M3 역할색 매핑 완료. **`fromSeed` 실측 대조**로 오버라이드가 필요한 역할 5개를 특정(§1.2)
  - `ThemeExtension AppColors` 필요 항목 확정: success·warning·map 3계열(M3 `ColorScheme` 에 없음)
  - `FLUTTER_FRONTEND_PLAN.md` 에 포인터 2곳 추가(§6 P6 · §7)
- [x] ✅ **D2** 에이전트 2개(`ui-implementer`·`design-system-auditor`) + 컨벤션 §9 **C-8** + `PROJECT_NOTES.md`
  - 전역 7개에 없는 역할이라 "에이전트 복제 금지" 정책과 충돌하지 않는다
  - 체크리스트 분담을 명시: **C-1~C-7 = `convention-auditor` / C-8 = `design-system-auditor`** (중복 지적 방지)
  - `PROJECT_NOTES.md` 에 프론트 전용 절 신설 — 이 둘만 `frontend/` 에서 동작한다는 사실이 없으면 백엔드 Gradle 사실을 잘못 적용한다
- [x] ✅ **D3** 테마 토큰 코드화 — `app/theme/{app_theme,app_colors,app_typography,app_spacing}.dart`
  - `AppColors extends ThemeExtension` 신설 — success·warning·map 3계열 + `context.appColors` 축약
  - `AppTypography` 신설 — 11개 슬롯 + `mono()`(tabularFigures) + `caption()`
  - `AppSpacing`: `smd`(12) 추가 · `radiusSm` **6→8**(칩·태그). **기존 이름은 그대로** — 24개 파일이 이미 쓰고 있다
  - `AppTouch` 신설(min 48 / primary 56) — 터치 크기는 취향이 아니라 안전 요구라 별도 클래스로 뺐다
  - `AppTheme`: 컴포넌트 테마 12종. **버튼 4종·입력·아이콘버튼에 48dp 를 전역 보장**해 화면마다 챙기다 빠뜨리는 걸 막았다
  - ⚠️ 반경 용도 이동 — 카드 12→**20**, 버튼·입력 6→**12**. 화면별 잔재는 D5~D8 에서 정리
  - **검증**: `flutter analyze` 무경고 · `dart format` 변경 0 · `flutter test` **203/203**
- [x] ✅ **D4** `core/ui` 공용 컴포넌트 + 셸
  - 신규 5파일: `app_tone.dart`(`AppTone` + 색 해석기) · `app_status_chip.dart`(`AppStatusChip`·`AppTag`) · `app_action_button.dart`(`AppActionButton`·`AppActionDone`) · `skeleton_box.dart`(`SkeletonBox`·`SkeletonList`) · `offline_banner.dart`
  - ⭐ **`AppTone` 이 핵심이다.** 위젯은 톤(`success`)만 고르고 색(`appColors.successContainer`)은 고르지 않는다. M3 `ColorScheme` 과 `AppColors` 가 반씩 갖고 있는 걸 여기서 합쳐, 같은 의미가 화면마다 다른 색으로 새는 걸 막는다
  - ⚠️ **확장 색은 필요한 톤에서만 읽는다** — `switch` 밖에서 `context.appColors` 를 미리 꺼냈더니 `AppTone.error` 하나 쓰는 `ErrorView` 까지 `ThemeExtension` 등록에 묶여 기존 위젯 테스트 3건이 죽었다. 지연 조회로 고치고, 테스트 하네스도 `AppTheme.light` 를 얹도록 바꿨다(기본 테마로 띄우면 앱에선 없는 상태를 검증하게 된다)
  - 기존 4종은 **API 유지, 외형만** 교체(호출부 11곳 무변경). `AsyncSection` 에 `loading` 빌더만 추가 — 목록 화면이 스켈레톤을 넘길 수 있게
  - `app_shell.dart` — 폰 프레임에 좌우 테두리. 모니터에서 가운데 정렬만 하면 그냥 좁은 웹페이지로 읽힌다
  - **검증**: `flutter analyze` 무경고 · `dart format` 변경 0 · `flutter test` **215/215**(신규 위젯 테스트 12건)
- [x] ✅ **D5** 기사 — 로그인 · 운행 시작 (커밋 `84bf84e`)
  - 방향 2지 선택을 나란히 + **기본 선택 없음**. 위아래로 쌓으면 위쪽이 기본값처럼 읽히고, 등하원이 뒤바뀌면 명단 장소가 통째로 달라진다
  - "시작해야 명단이 온다"는 안내 배너 — 없으면 기사가 빈 명단 탭을 고장으로 읽는다
- [x] ✅ **D6** 기사 — 오늘의 노선(지도) · 위치 보고 (커밋 `e57b05d`)
  - 정차 3상태(다음=`primaryContainer` / 예정=`surfaceContainer` / 완료=`opacity .6`). 진하게 튀는 카드가 하나뿐이라 "다음에 갈 곳"이 1초에 읽힌다
  - ETA 는 도메인 `etaLabel` 경유(초 노출 없음), 지도는 `mapBase`/`mapLine`
- [x] ✅ **D7** 기사 — **승하차 기록 · 운행 종료** ★ (커밋 `5accc11`)
  - `ride_status_chip.dart` **신설** — §4 계약의 유일한 구현. 라벨은 `RideStatus.label` 을 그대로 쓴다(여기서 다시 적으면 도메인과 두 벌이 되어 갈라진다)
  - `NoShowBadge` 는 칩이 아니라 **태그** — 미승차여도 단계는 여전히 `대기`다. 칩을 바꿔치우면 "아직 태울 수 있다"가 사라진다
  - 전송 중엔 칩이 이전 상태 그대로 + **버튼이 사라진다**(잠긴 버튼을 남기면 연타한다). 실패 시 테두리 `error` + 같은 줄 `다시 시도`
  - 액션 열 **112dp 고정** — 줄마다 버튼 위치가 흔들리면 흔들리는 차 안에서 조준이 안 된다. 글자 115% 초과면 행을 세로로 접는다
- [x] ✅ **D8** 관리자 4화면 (커밋 `f7c472d`)
  - 시안이 없어 기사 앱 컴포넌트·토큰을 데스크톱 폭으로 확장. **새 색·새 반경 없음**, 새로 정한 건 행 밀도뿐
  - 알림 유형별 톤을 기사 앱과 일치시킴. 새 알림만 `surfaceContainer`(전부 칠하면 새 것이 안 보인다)
  - 48dp 최소값은 데스크톱에서도 유지 — 태블릿 관제를 배제하지 않았다
  - **검증(D5~D8 통합)**: `flutter analyze` 무경고 · `dart format` 변경 0 · `flutter test` **215/215**
- [~] 🟡 **D9** 감사 ✅ / 감사 지적 대응 ✅ / 브라우저 육안 점검 ⬜
  - 보고서: **`frontend/report/2026-07-29-design-system-audit.md`** (37파일 6,095줄 전수) — **High 2 · Medium 5 · Low 4**, 전부 대응 완료
  - **토큰 규율은 깨끗했다**: 검사 범위 전체에서 `Color(0x…)` **0건** · `EdgeInsets`/`SizedBox`/`BorderRadius` 숫자 리터럴 **0건** · `TextStyle` 직접 생성 **0건** · 낙관적 UI **0건**. 결함은 예상대로 **병렬 작업의 이음매**에 몰렸다
  - **H1(가장 중요)** — 관리자 알림함이 승차·하차·인계를 **전부 `success`(초록)** 로 칠하고 있었다. 하차는 하원에서 아직 인계가 남은 중간 단계라, 색이 같으면 관리자가 목록만 훑고 "인계 안 된 아이"를 완료로 읽는다. **§4 가 막으려던 사고 그 자체.** 원인은 코드가 아니라 문서였다 — `DESIGN_SYSTEM.md` §5.2 가 "승하차 `success`" 라고 뭉뚱그려 §4 와 충돌했고, 구현은 §5.2 를 따랐다. **문서·코드 둘 다** 고쳤고 §4 우선 원칙을 명시했다
  - **H2** — `SegmentedButton` 이 M3 기본 40dp(§3.3 금지값). `ChoiceChip` 32dp(M3)도 같이 걸렸다 → 화면이 아니라 **`app_theme.dart` 에서 전역 보장**(`segmentedButtonTheme`·`chipTheme`)
  - M1 `AppActionDone` `fontSize: 14` 제거 / M2 카드 반경 12→20 2곳 / M3 위 테마로 해결 / M4 지도 마커가 `secondary`·`tertiary`(§1 미정의 역할)를 쓰던 것 → §5.3 역할색, 경로선 5→**9** / M5 마커 라벨 `TextStyle` → `textTheme`
  - L1 ETA 문구는 **문서를 구현에 맞췄다**(구현이 `0초 = 출발` 케이스를 하나 더 다뤄 더 정확하다) / L2 `_RouteSummary` 200%에서 2×2 접힘 / L3 `AppSpacing.xs`→`radiusXs` / L4 노선 목록 빈 상태에 "배차 화면으로" 추가
  - **문서 보강 3건**(같은 판단이 반복되지 않게): §3.2 카드/행/배너 반경 판단표 · §3.3 읽기전용 칩 vs 선택 칩 · §5.2 승하차 톤 §4 위임
  - ⭐ **회귀 테스트 추가** — `test/features/notification/notification_tone_contract_test.dart`. 기사 칩 톤과 관리자 알림 톤을 **직접 대조**한다. 톤을 되돌리면 2건이 깨지는 것까지 확인했다(mutation check). 이런 어긋남은 화면을 나눠 만들 때마다 다시 생기므로 눈이 아니라 테스트가 지킨다
  - **검증**: `flutter analyze` 무경고 · `dart format` 변경 0 · `flutter test` **220/220**(+5)

---

## 화면 ↔ 파일 대응표

에이전트에게 파일 집합을 넘길 때 이 표를 그대로 쓴다. **D5~D8 의 파일 집합은 서로 겹치지 않는다.**

| D | 화면 | 파일 |
|---|---|---|
| — | 반응형 셸 | `app/shell/app_shell.dart` (4개가 공유 → **메인이 직접**) |
| D5 | 로그인 | `features/auth/presentation/screen/login_screen.dart` · `widget/quick_login_panel.dart` |
| D5 | 운행 시작 | `features/rideevent/presentation/widget/drive_start_view.dart` |
| D6 | 오늘의 노선 | `features/routing/presentation/screen/driver_route_screen.dart` · `widget/route_stop_tile.dart` · `widget/route_plan_map.dart` |
| D6 | 위치 보고 | `features/location/presentation/widget/driver_location_card.dart` |
| D7 | 승하차 기록 ★ | `features/rideevent/presentation/screen/driver_roster_screen.dart` · `widget/roster_student_tile.dart` · **`widget/ride_status_chip.dart`(신규)** |
| D7 | 운행 종료 | `features/rideevent/presentation/widget/end_drive_sheet.dart` |
| D8 | 관제 지도 | `features/location/presentation/screen/admin_monitor_screen.dart` · `widget/monitored_bus_tile.dart` |
| D8 | 배차 | `features/routing/presentation/screen/admin_dispatch_screen.dart` · `widget/excluded_students_banner.dart` · `widget/admin_tenant_badge.dart` |
| D8 | 노선 목록 | `features/routing/presentation/screen/admin_route_list_screen.dart` · `widget/route_plan_card.dart` |
| D8 | 알림함 | `features/notification/presentation/screen/admin_notification_screen.dart` · `widget/notification_tile.dart` · `widget/connection_status_chip.dart` |

---

## 에이전트 운용 규칙 (D5~D8)

이전 세션에서 **에이전트 4개 중 3개가 토큰 한도로 중도 사망**했다(`FLUTTER_FRONTEND_PLAN.md` §7). 그때 배운 걸 규칙으로 굳혔다.

1. **에이전트는 git 명령을 쓰지 않는다.** 편집만 하고 끝낸다 → 보고 단계에서 죽어도 파일은 디스크에 남는다
2. **워크트리 격리를 쓰지 않는다.** 격리 워크트리에서 죽으면 임시 디렉터리째 유실된다. 파일 집합이 겹치지 않으므로 같은 트리에서 병렬로 충분하다
3. **자기 담당 파일만 편집.** 공용 파일(`app/theme`·`core/ui`·`application/`·`data/`)은 **읽기만**
4. **로직·API·provider 를 바꾸지 않는다.** 바꿔야 할 것 같으면 고치지 말고 보고에 적는다
5. **보고는 10줄 이내** — 변경 파일 목록 + 미해결 항목. 서술 금지
6. 커밋은 에이전트 반환 직후 **메인이** 한다

---

## 세션 재개 지점

### 지금 상태

- **D0~D8 완료·커밋됨. D9 은 감사·대응까지 끝났고 브라우저 육안 점검만 남았다**
- 기준선: `flutter analyze` 무경고 · `dart format` 변경 0 · `flutter test` **220/220** · Flutter 3.44.8 / Dart 3.12.2 (`/opt/homebrew/bin/flutter`)

### 다음에 할 일

1. `design-system-auditor` 보고서(`frontend/report/2026-07-29-design-system-audit.md`) 확인 → High 대응
2. **브라우저 육안 점검** — Docker 기동은 사용자에게 먼저 요청한다
3. 아래 §지시서 수용 기준 표 채우기

### ⚠️ 에이전트 병렬 작업 실측 (이번 세션)

`ui-implementer` 4개를 **워크트리 격리 없이, git 명령 금지로** 동시에 돌렸다. **4개 전부 완주**했고 충돌 0건이었다(2026-07-28 세션의 3/4 사망과 대비된다). 성공 요인으로 보이는 것:

- 커밋을 메인이 하니 에이전트가 index 를 두고 경쟁하지 않는다
- 파일 집합을 겹치지 않게 나눴다 — 같은 트리라도 서로의 편집을 본 적이 없다
- 프롬프트에 **읽을 문서 순서와 담당 파일 목록을 못 박아** 탐색 비용을 없앴다(이전 실패는 전부 탐색 단계에서 토큰을 태운 것으로 보인다)

### 화면 이식에서 남긴 미해결 (로직 변경이 필요해 손대지 않은 것)

| 항목 | 내용 |
|---|---|
| 담당 버스 정보 | 운행 시작 화면이 **`busId` 밖에 못 보여준다.** 호차명·차량번호·정원·배정인원은 `GET /api/buses/me` 응답에 있지만 앱이 그 응답을 통째로 들고 있는 곳이 없다(`auth` 가 `busId` 만 뽑아 세션에 얹는다). bus feature repository 가 필요하다 |
| `NO_SHOW` | 명단에서 **항상 `false`** 다. 서버가 미승차를 **알림으로만** 보내고 명단·승하차 응답에 담지 않아 화면이 알 방법이 없다. 표기 규칙(§4)은 구현해 뒀으니 데이터가 생기면 인자만 채우면 된다 |
| 노선 화면의 학생 이름 | `stops[]` 는 `studentId` 만 준다. 이름은 운행 세션 명단에만 있다 |
| 전송 실패 대상 | 컨트롤러가 실패에 `studentId` 를 싣지 않아, 화면이 `_failed` 를 자체 계산한다. 컨트롤러가 싣게 되면 그 계산은 통째로 사라진다 |

---

## 검증

| 단계 | 명령 | 기준 |
|---|---|---|
| 각 커밋 | `cd frontend && flutter analyze` | 무경고 |
| 각 커밋 | `dart format --set-exit-if-changed lib/` | 변경 0 |
| D3·D4·D9 | `flutter test` | **203건 이상 전건 통과** |
| D9 | `design-system-auditor` 전수 감사 | C-8 High 0건 → `frontend/report/2026-07-29-design-system-audit.md` |
| D9 | 브라우저 `http://localhost/` | 기사·관리자 전 화면 · **라이트/다크 둘 다** |
| D9 | 지시서 §11 수용 기준 9항목 | 아래 표에 결과 기록 |

### 지시서 §11 수용 기준 대조 (D9 에서 채운다)

| # | 기준 | 결과 |
|---|---|---|
| 1 | 학생 1명 승차 기록이 **탭 1회**로 끝난다 | ⬜ |
| 2 | 운전석에서 **"다음에 할 일"** 이 1초 안에 읽힌다 | ⬜ |
| 3 | `하차`와 `인계완료`가 시각적으로 명확히 구분된다 | ⬜ |
| 4 | 잔류 학생이 있을 때 **운행 종료가 막혀 있음**이 분명히 보인다 | ⬜ |
| 5 | 없는 데이터(사진·연락처·통계)를 쓰지 않았다 | ⬜ |
| 6 | 라이트/다크 모두에서 대비가 충분하다 | ⬜ |
| 7 | 로딩·빈 상태·에러가 모든 화면에 정의돼 있다 | ⬜ |
| 8 | 화면의 이름·정류장이 시드 데이터와 일치한다 | ⬜ |
| 9 | 학생 3명 기준으로 자연스럽고 25명까지 안 무너진다 | ⬜ |

---

## 결정 기록

- **2026-07-29 · `fromSeed` 를 버리지 않고 5개 역할만 오버라이드한다.** 실측 결과 시안의 surface·outline·error 계열은 `fromSeed(#2563EB)` 출력과 사실상 동일했고, 다른 건 primary 계열 4개 + light `onErrorContainer` 뿐이었다. 팔레트를 손으로 다시 짜면 앞으로 M3 가 쓰는 다른 역할색이 시드와 어긋난다. 근거·실측표는 `DESIGN_SYSTEM.md` §1.2
- **2026-07-29 · 폰트를 번들하지 않는다.** 한글 웹폰트는 서브셋해도 현재 번들(2.2MB)보다 커지고, `google_fonts` 는 nginx 단일 진입점 구성에 외부 CDN 의존을 하나 추가한다. Mono 역할은 `FontFeature.tabularFigures()` 로 대체. 근거는 `DESIGN_SYSTEM.md` §2.2 — **되돌릴 수 있는 결정**이다
- **2026-07-29 · 오프라인 배너 문구를 시안대로 쓰지 않는다.** 시안은 `기록은 저장 후 재전송됩니다` 인데 클라이언트에 재전송 큐가 없다. 그대로 쓰면 거짓말이 된다 → `기록이 전송되지 않을 수 있습니다`. `DESIGN_SYSTEM.md` §8
- **2026-07-29 · 관리자 화면 시안은 없다.** 시안 푸터가 "다음 버전"으로 미뤘다. 토큰·컴포넌트를 데스크톱 폭으로 확장해 적용하고 **새 색·새 반경을 만들지 않는다**. `DESIGN_SYSTEM.md` §10
