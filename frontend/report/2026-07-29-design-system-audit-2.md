# 디자인 시스템 감사 (2차) — 2026-07-29 · 정차 그룹핑 변경분

검사 범위: 이번 변경분 8개 파일 + 함께 읽은 도메인 2개
근거: `docs/DESIGN_SYSTEM.md`(§0·§3·§4·§5.2·§5.3·§5.4·§7), `docs/FLUTTER_CODE_CONVENTIONS.md` §9 **C-8**
1차 감사(같은 날 `2026-07-29-design-system-audit.md`, 11건)는 커밋 `5d82bd2` 로 처리 완료 — 이 문서는 그 이후 변경분만 본다.

## 요약

| 심각도 | 건수 |
|---|---|
| High (막아야 함) | 1 |
| Medium (고치는 게 낫다) | 3 |
| Low (일관성/취향) | 3 |

하드코딩 색·`TextStyle` 직접 생성·48dp 미만 터치 타깃·`RideStatusChip` 재구현은 **이번 변경분에 하나도 없다.**

---

## High

### 1. 하원 그룹의 접힘 요약이 §4 상태 라벨을 다른 뜻으로 쓴다

- 위치: `lib/features/rideevent/domain/roster_stop_group.dart:63-66` (문구 생성) → `lib/features/rideevent/presentation/widget/roster_stop_group_card.dart:96-101` (렌더)
- 위반: `collapsedSummary` 가 `'$kindLabel 완료'` / `'$kindLabel 대기 N명'` 으로 조립된다. 하원(`kindLabel == '하차'`)에서
  - 그룹이 끝났을 때 → **`하차 완료 · 1명`**. 그런데 `isDone` 의 기준은 `nextActionFor == null` 이라 하원에서는 **`HANDED`(보호자 인계 완료)** 여야 참이다. §4 표에서 `하차 완료` 는 **인계가 아직 남은 중간 상태**의 라벨이다.
  - 그룹이 안 끝났을 때 → **`하차 대기 1명`**. 이 1명은 `ALIGHTED` 이고 남은 동작이 **인계**인 경우가 포함된다. 이미 차에서 내린 학생을 "하차 대기"로 부른다.
- 근거: `DESIGN_SYSTEM.md` §4(라벨 계약: `대기`/`승차 완료`/`하차 완료`/`보호자 인계 완료`), §4.1(하원은 `하차 → 인계`), §7-7(라벨 문자열은 한 곳에서만 정의), C-8 High 4번째 항목
- 왜 문제인가: 기본 동작이 "끝난 그룹은 접는다" 라서 하원에서 **정상 완료된 정차의 기본 표시 문구가 `하차 완료`** 다. 인계까지 끝난 정차를 인계가 남은 것처럼 읽게 되고, 반대로 접힌 미완료 그룹의 `하차 대기 1명` 은 기사에게 "아직 안 내린 아이가 있다"로 읽힌다 — 잔류 인원 경고(`_EndDriveBar` 의 `N명이 아직 차에 있습니다`)와 뜻이 겹쳐 혼선이 커진다.
- 제안: 그룹 요약에 §4 라벨 어휘를 재사용하지 않는다. `처리 완료 · 2명` / `남은 처리 1명 · 눌러서 펼치기` 처럼 **그룹 단위 어휘**로 바꾸거나, 하원이면 남은 동작(`nextActionFor`)의 라벨을 `RideStatusChip` 의 매핑에서 가져와 `인계 대기 1명` 으로 낸다. 문구를 도메인에 둔 구조 자체는 §5.4-3 대로 맞다.

---

## Medium

### 2. 지도에서 `다음 정차` 라벨 칩이 없다 — 다음/예정이 모양+색으로만 갈린다

- 위치: `lib/core/map/impl/flutter_map_adapter.dart:212-238`, 호출부 `lib/features/routing/presentation/screen/driver_route_screen.dart:271-282`
- 위반: §5.3 은 다음 정차 마커를 "34 원형 채움 + **옆에 `다음 정차` 라벨 칩**"으로 정한다. 구현은 채움 원(다음) vs 3px 테두리 원(예정)까지만 있고 라벨 칩이 없다.
- 근거: `DESIGN_SYSTEM.md` §5.3, §0-1(색 + 아이콘/모양 + **텍스트 라벨** 3중 표기)
- 왜 문제인가: 채움/테두리는 모양 신호라 색만 쓰는 것보다는 낫지만, 직사광선에서 파란 채움과 파란 테두리는 실제로 잘 안 갈린다. 지도만 보고 "다음에 갈 곳"을 잘못 짚으면 경로 자체가 틀어진다. (완화 요소: 지도 위 `_NextStopCard` 가 같은 순번 배지를 띄워 대조는 가능하다.)
- 제안: `MapMarkerSpec` 에 라벨 칩 필드를 하나 더 두고 `MapMarkerKind.stop` 옆에만 붙인다. 포트를 늘리기 싫다면 최소한 §5.3 문장을 "다음 정차 카드가 라벨 역할을 대신한다"로 고쳐 문서와 코드를 맞춘다.

### 3. 앱바 2줄 제목이 글자 배율 1.3배부터 앱바 밖으로 넘친다

- 위치: `lib/app/shell/app_shell.dart:70-94` (`_title`), 부제 위젯 `lib/features/bus/presentation/widget/driver_app_bar_subtitle.dart`
- 위반: 실측(Flutter 위젯 테스트, 800×600, 기본 `AppBar`) — 제목 `titleLarge` + 부제 `bodySmall` 2줄 Column 의 rect 가

  | 배율 | 제목 rect | 부제 rect | 앱바 |
  |---|---|---|---|
  | 1.0 | top 2.5 | bottom 53.5 | 0~56 |
  | 1.3 | **top -4.5** | **bottom 60.5** | 0~56 |
  | 2.0 | **top -5.5** | **bottom 61.5** | 0~56 |

  (M3 `AppBar` 가 툴바 배율을 1.34로 클램프해 2.0에서도 더 커지지는 않는다. 오버플로 예외는 안 뜨지만 잘리거나 본문 위로 그려진다.)
- 근거: `DESIGN_SYSTEM.md` §7-5, C-8 Medium/High 공통 취지
- 왜 문제인가: 배율을 올려 쓰는 기사(운전석 사용자가 실제로 많이 그렇다)에게 제목이 상태바로 파고들고 부제가 본문 첫 줄과 겹친다. 부제는 "지금 내가 어느 차·어느 편인가"라 잘못 읽히면 안 되는 정보다.
- 제안: `AppBar(toolbarHeight:)` 를 `MediaQuery.textScalerOf(context).scale(...)` 로 계산하거나, 부제를 `bottom: PreferredSize` 로 내린다. 배율이 큰 구간에서는 부제를 숨기는 것도 방법이다(정보가 잘린 채 남는 것보다 낫다).

### 4. 시트 손잡이 크기가 토큰을 안 거친 리터럴

- 위치: `lib/features/routing/presentation/screen/driver_route_screen.dart:551-552` — `width: 44, height: 4`
- 위반: §7-6(간격 숫자 리터럴 금지). `4` 는 `AppSpacing.xs` 다.
- 근거: `DESIGN_SYSTEM.md` §7-6, §3.1, C-8 Medium 3번째
- 왜 문제인가: 이 파일의 나머지 치수는 전부 토큰이거나 주석으로 근거를 단 상수(`_size = 52`, `_badgeSize = 34`)인데 여기만 근거 없는 숫자다. 다음 사람이 "여기는 리터럴을 써도 되나 보다"로 읽는다.
- 제안: 높이는 `AppSpacing.xs`, 폭은 이름 붙인 `static const double _handleWidth = 44` 로 근거를 남긴다.

---

## Low

### 5. 그룹 태그 `하차` 가 파란 톤이라 §4 의 하차 톤(warning)과 어긋난다

- 위치: `lib/features/rideevent/presentation/widget/roster_stop_group_card.dart:132,164`
- 위반: 헤더 태그 톤이 `group.isDone ? neutral : primary` 라 하원 그룹에서 `하차` 태그가 `primaryContainer`(파랑)로 나온다. §4 는 하차를 `warningContainer` 로 정한다.
- 근거: `DESIGN_SYSTEM.md` §4, §5.2(알림 톤 각주 "§4 와 충돌하면 언제나 §4 가 이긴다"). 다만 §5.2 의 `RosterStopGroupCard` 항목은 이 태그의 **톤을 지정하지 않았다** — 그래서 High/Medium 이 아니다.
- 왜 문제인가: 같은 카드 안에서 헤더 태그 `하차`(파랑)와 학생 행 상태 칩 `하차 완료`(주황)가 같은 단어를 다른 색으로 낸다. 색을 상태 단서로 학습한 사용자에게 잡음이 된다.
- 제안: 태그 톤을 `direction` 에 따라 `승차 → primary` / `하차 → warning` 으로 매핑하거나, §5.2 에 "그룹 태그는 진행 상태(진행 중/완료) 톤이지 §4 상태 톤이 아니다"를 명시해 의도를 못박는다.

### 6. 지나온 정차 마커가 순번을 잃는다

- 위치: `lib/core/map/impl/flutter_map_adapter.dart:239-244`
- 위반: `visitedStop` 이 체크 아이콘만 그려 `spec.label`(순번)을 버린다. `driver_route_screen.dart:281` 은 라벨을 넘기고 있다.
- 근거: `DESIGN_SYSTEM.md` §5.4-3(노선 마커 번호와 명단 그룹 번호가 맞아야 한다)
- 왜 문제인가: 명단에는 완료 그룹도 배지 ②로 남는데 지도에서는 번호가 사라져 대조가 끊긴다. 완료 후 되짚어볼 때만 생기는 문제라 Low.
- 제안: 체크 아이콘 대신 순번 텍스트를 유지하고 완료는 톤(`surfaceContainerHigh`)+테두리로 구분하거나, 아이콘과 숫자를 같이 넣는다.

### 7. 빈 상태 두 곳에 다음 행동 버튼이 없다 (기존 이월)

- 위치: `driver_route_screen.dart:47-53`(배차된 버스 없음), `driver_roster_screen.dart:127-133`(태울 학생 없음)
- 근거: `DESIGN_SYSTEM.md` §6, C-8 Low 2번째
- 이번 변경분에서 새로 생긴 건 아니고, 둘 다 앱 안에서 할 수 있는 다음 행동이 실제로 없다(관리자 요청·운행 종료는 다른 화면). 설명 문구가 그 역할을 하고 있어 **조치 없이 남겨도 된다고 본다.** 다음 감사에서 다시 파지 않도록 여기 남긴다.

---

## 위반 아님으로 판단한 것

- **`EdgeInsets.all(48)`** (`flutter_map_adapter.dart:102`) — 화면 여백이 아니라 카메라 `CameraFit` 여백이다. 지도 좌표 맞춤 파라미터라 `AppSpacing` 대상이 아니다.
- **`Icon(size: 18/20/24)` 전반** — 디자인 시스템에 아이콘 크기 토큰이 없다. 규칙이 없으면 지적이 아니다.
- **`_badgeSize = 32/34`, `_size = 52`, `_thumb = 40`, `_actionColumn = 112`** — 전부 §5.2·§5.3 이 명시한 값이고 주석에 근거가 달려 있다. 게다가 배지는 `* MediaQuery.textScalerOf(context).scale(1)` 로 배율에 비례해 커진다(§5.2 요구사항 충족).
- **`RouteStopGroupTile` 패딩 12(§5.2 문서값 14)** — 14는 토큰 체계에 없는 값이다. §7-6(토큰 경유)이 §5.2 의 수치보다 우선한다고 봤다.
- **`Colors.black26` 마커 그림자**(`flutter_map_adapter.dart:253`) — 이번 변경분이 아니다(1차 감사 이후 그대로). §3.4 스펙은 `0 2px 8px rgba(0,0,0,.35)` 인데 코드는 blur 4 / 알파 .26 이다. 그림자에는 테마 토큰이 없어 리터럴 자체는 불가피하다. 값만 스펙에 맞추면 되는 잔여 항목으로 남긴다.
- **마커 크기 40 원형 · 학원 마커가 원형**(`flutter_map_adapter.dart:164-165, 205-210`) — §5.3 은 정차 34 원형·학원 36 **사각 radius 10** 이다. 다만 이 코드는 이번에 안 바뀌었고 `route_plan_map.dart` 에서 이미 같은 모양으로 쓰이고 있었다. 기존 이월 항목으로 분류한다.
- **면색 위계** — 노선 탭은 시트 `surface` 위에 정차 카드 `surfaceContainer`(다음 정차만 `primaryContainer`), 명단 탭은 카드 `surface`+테두리 안에 학생 행 `surfaceContainer` 로 **양쪽 다 한 단씩 벌어져 있다.** 명단에서 고친 문제가 노선 탭에는 없다.
- **낙관적 UI** — 그룹 진행률·완료 판정이 전부 `RosterStudent.status`(서버 반영분)에서 나오고, 전송 중 표시는 `RosterStudentTile` 이 그대로 담당한다. 그룹이 상태를 앞질러 확정하는 곳은 없다.
- **터치 타깃** — 그룹 헤더 56(`AppTouch.primary`), 다음 정차 요약 56, 방향 카드 56, 카메라 버튼 52, `SegmentedButton` 48. 48 미만 없음.
- **상태 칩 재구현** — 명단의 상태 표기는 전부 `RosterStudentTile` → `RideStatusChip` 경유. 화면에서 다시 만든 곳 없음.
- **정류장 이름 지어내기(§5.4-5)** — `RouteStopGroup.title`·`RosterStopGroup.title` 둘 다 `label ?? '$seq번 정차'` 다. 시작 전 화면에 가짜 이름이 뜨는 경로는 없다.
