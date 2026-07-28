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
- [ ] ⬜ **D3** 테마 토큰 코드화 — `app/theme/{app_theme,app_colors,app_typography,app_spacing}.dart`
- [ ] ⬜ **D4** `core/ui` 공용 컴포넌트 — `AppStatusChip`·`AppActionButton`·`SkeletonBox`·`OfflineBanner` + 기존 4종 외형 교체
- [ ] ⬜ **D5** 기사 — 로그인 · 운행 시작 *(에이전트)*
- [ ] ⬜ **D6** 기사 — 오늘의 노선(지도) · 위치 보고 *(에이전트)*
- [ ] ⬜ **D7** 기사 — **승하차 기록 · 운행 종료** ★ *(에이전트)*
- [ ] ⬜ **D8** 관리자 4화면 *(에이전트)*
- [ ] ⬜ **D9** 감사 + 브라우저 육안 점검 + 문서 마감

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

- **D0~D2 완료·커밋됨**
- 기준선: `flutter analyze` 무경고 · `flutter test` **203/203** · Flutter 3.44.8 / Dart 3.12.2 (`/opt/homebrew/bin/flutter`)

### 다음에 할 일

**D3** 부터 순서대로. D3·D4 가 끝나기 전에는 D5~D8 에이전트를 띄우지 않는다(공용 토큰이 없으면 화면이 매직넘버로 채워진다).

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
