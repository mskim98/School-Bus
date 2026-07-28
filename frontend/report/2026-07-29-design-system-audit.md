# 디자인 시스템 전수 감사 (D9)

- 일자: 2026-07-29
- 대상: `frontend/lib/**` 중 `presentation/`(screen·widget) · `core/ui/` · `app/theme/` · `app/shell/` — 37개 파일 6,095줄
- 기준: `docs/DESIGN_SYSTEM.md`, `docs/FLUTTER_CODE_CONVENTIONS.md` §9 **C-8**, `docs/DESIGN_BRIEF_DRIVER_MOBILE.md` §3·§7
- 방법: 전 파일 통독 + 토큰 우회 패턴 grep(`Color(0x`·`TextStyle(`·`fontSize`·`EdgeInsets`/`SizedBox`/`BorderRadius` 숫자 리터럴) + Flutter 3.44.8 프레임워크 기본값 실측(`chip.dart`·`segmented_button.dart`)
- **코드는 수정하지 않았다.** 보고만 한다.

---

## 요약

| 심각도 | 건수 | 제목 |
|---|---|---|
| **High** | 2 | H1 알림 화면의 승하차 톤이 §4 상태 계약과 어긋난다<br>H2 배차 화면 `SegmentedButton` 높이 40dp (§3.3 금지값) |
| **Medium** | 5 | M1 `AppActionDone` 의 `fontSize: 14`<br>M2 카드 반경 12/20 혼용<br>M3 노선 목록 `ChoiceChip` 시각 높이 32dp<br>M4 지도 마커가 §5.3 이 지정하지 않은 역할색을 쓴다<br>M5 지도 마커 라벨이 `TextStyle` 직접 생성 |
| **Low** | 4 | L1 ETA 문구가 §7-8 규정 문구와 다르다<br>L2 `_RouteSummary` 4열 고정 `Row` — 200% 확대에서 잘린다<br>L3 간격 토큰을 반경으로 사용<br>L4 노선 목록 빈 상태에 "다음 행동" 버튼이 없다 |

**전체 인상.** 토큰 규율은 매우 잘 지켜졌다 — 검사 범위 전체에서 `Color(0x…)` 리터럴 **0건**, `EdgeInsets`/`SizedBox`/`BorderRadius` 숫자 리터럴 **0건**, `TextStyle` 직접 생성 **0건**, `fontSize` 지정 **1건**뿐이다. 낙관적 UI도 없고(컨트롤러까지 확인), §4 라벨 문자열 4종은 `RideStatus` enum 한 곳에만 있다. 남은 결함은 대부분 **병렬 작업의 이음매** — 같은 개념을 두 팀이 다르게 해석한 자리(H1·H2·M2·M3)에 몰려 있다.

---

## High

### H1. 알림 화면의 승하차 톤이 §4 상태 계약과 어긋난다

- **위치**: `lib/features/notification/presentation/widget/notification_tile.dart:109-116`

```dart
boardDone('BOARD_DONE', '승차', Icons.login, AppTone.success),
alightDone('ALIGHT_DONE', '하차', Icons.logout, AppTone.success),
handoverDone('HANDOVER_DONE', '인계', Icons.handshake_outlined, AppTone.success),
```

- **위반**: 같은 사건이 기사 화면과 관리자 화면에서 **다른 톤**으로 나온다.

| 사건 | 기사 앱 (`ride_status_chip.dart:35-40`) | 관리자 알림함 (`notification_tile.dart`) |
|---|---|---|
| 승차 | `primary` (파랑) | `success` (초록) |
| 하차 | `warning` (주황) | `success` (초록) |
| 인계 | `success` (초록) | `success` (초록) |

- **근거**: §4 머리말 — *"라벨 문자열·아이콘·색은 기사 앱·관리자 웹·(향후) 학부모 앱에서 **동일해야 한다**"*. §4 표는 승차 `primaryContainer` / 하차 `warningContainer` / 인계 `successContainer` 로 못 박았다.
- **⚠️ 문서 내부 충돌을 밝힌다**: §5.2 마지막 줄은 *"알림 유형별 톤: 미승차 `error` · 근접 `primary` · **승하차 `success`** · 노선 배포 `neutral`"* 이라고 적었고, 구현은 **이 줄을 그대로 따랐다**. 즉 이 코드는 §5.2 를 어긴 게 아니라 §5.2 와 §4 가 서로 다른 값을 지시하고 있고 그중 §5.2 를 골랐다. 다만 §5.2 의 "승하차"는 알림을 **한 덩어리 분류**로 본 표기인 반면, 구현은 이미 `boardDone`/`alightDone`/`handoverDone` 세 항목으로 쪼개 놨다 — 쪼갠 이상 §4 의 세 톤을 적용할 수 있었다. 그리고 §4 는 ★ 표시가 붙은 "임의로 바꾸지 않는다" 절이므로 충돌 시 §4 가 이긴다고 읽는 게 맞다.
- **왜 문제인가**: 하차는 하원에서 **아직 인계가 남은 중간 단계**다. §4 가 하차를 `warning` 으로 둔 이유가 그것이고, `ride_status_chip.dart:30-34` 주석도 *"색까지 같으면 기사가 '내려줬다'와 '넘겼다'를 구분하지 않게 되고, 그 순간 학부모에게 나가는 알림이 어긋난다"* 고 적어 뒀다. 그런데 관리자 알림함에서는 하차와 인계가 **똑같은 초록**이라, 관리자가 알림 목록만 훑으면 "아직 인계 안 된 아이"를 완료된 것으로 읽는다. 정확히 §4 가 막으려던 사고다.
- **제안**: `_NotificationKind` 의 톤을 §4 에 맞춘다 — `boardDone → AppTone.primary`, `alightDone → AppTone.warning`, `handoverDone → AppTone.success` (나머지 `approach`·`noShow`·`routePublished` 는 §5.2 대로 이미 맞다). 동시에 `DESIGN_SYSTEM.md` §5.2 의 "승하차 `success`" 한 줄을 "승하차 알림은 §4 상태 톤을 따른다"로 고쳐 충돌을 없앤다. **어느 쪽을 택하든 문서와 코드 중 하나는 반드시 같이 고쳐야 한다** — 지금은 두 규칙이 공존해서 다음 화면도 같은 실수를 반복한다.

### H2. 배차 화면 `SegmentedButton` 이 §3.3 금지값 40dp 로 그려진다

- **위치**: `lib/features/routing/presentation/screen/admin_dispatch_screen.dart:107-118`

```dart
SegmentedButton<RouteDirection>(
  segments: [ /* 등원 / 하원 */ ],
  selected: {state?.direction ?? RouteDirection.pickup},
  onSelectionChanged: ...,
)   // ← style 없음
```

- **위반**: `style` 을 주지 않아 Flutter M3 기본값이 그대로 적용된다. 실측 — `segmented_button.dart:1280` `minimumSize: WidgetStatePropertyAll(Size.fromHeight(40.0))`. 즉 **시각 높이 40dp**이며, §3.3 표는 40dp 를 `**금지**` 로 명시했다.
- **근거**: §3.3(터치 타깃) + §10(*"48dp 터치 최소값은 데스크톱에서도 유지한다 — 마우스라고 줄이지 않는다"*) + C-8 High 3번 항목.
- **같은 위젯을 쓰는 다른 두 곳은 고쳐져 있다** — 정확히 병렬 작업의 이음매다:
  - `features/routing/presentation/screen/driver_route_screen.dart:100-104` — `minimumSize: const Size.fromHeight(AppTouch.min)` + 주석 *"기본 높이가 40 이라 터치 최소값(48)에 미달한다"*
  - `features/location/presentation/widget/driver_location_card.dart:109-113` — 동일 처리 + 주석 *"기본 높이 40 은 금지값이다(§3.3)"*
- **정확히 하자면**: 프레임워크가 `MaterialTapTargetSize.padded` 기본값으로 위아래 여백을 채워 **히트 영역 자체는 48dp** 다(`segmented_button.dart:678-684`). 따라서 "손가락이 안 닿는" 수준의 결함은 아니다. 그러나 §3.3 이 금지한 것은 값 40 자체이고, 이 프로젝트가 같은 위젯을 두 번이나 명시적으로 48 로 올린 이상 여기만 40 인 것은 규칙 위반이자 불일치다.
- **왜 문제인가**: 관리자 배차는 **되돌릴 수 없는 확정**으로 이어지는 화면이고, 방향(등원/하원) 선택이 그 입력의 절반이다. 잘못 고르면 노선 전체가 뒤집힌다. §10 이 태블릿 관제를 배제하지 않는다고 못 박은 만큼 데스크톱 화면이라는 이유로 예외를 둘 수 없다.
- **제안**: 기사 화면 두 곳과 동일하게 `style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(AppTouch.min))` 을 붙인다. 세 곳에서 반복되는 만큼 **`app_theme.dart` 에 `segmentedButtonTheme` 를 추가해 전역 보장**하는 편이 낫다 — `filledButtonTheme`·`iconButtonTheme` 를 전역으로 둔 것과 같은 이유(§3.3 *"버튼마다 챙기면 반드시 빠뜨리는 곳이 생기므로"*)이며, 실제로 이번에 빠뜨렸다.

---

## Medium

### M1. `AppActionDone` 이 텍스트 스케일 밖의 `fontSize: 14` 를 쓴다

- **위치**: `lib/core/ui/app_action_button.dart:105-111`

```dart
style: Theme.of(context).textTheme.labelLarge?.copyWith(
  fontSize: 14,
  color: AppTone.success.onContainer(context),
),
```

- **위반**: §7-2 *"위젯에 `TextStyle(fontSize: …)` 직접 생성 금지 — `textTheme` 슬롯 경유"*. C-8 Medium 2번.
- **근거**: §2.1 스케일에 14 라는 값이 아예 없다(11·12·13·15·17·20·26·40). 검사 범위 전체에서 `fontSize` 를 지정한 유일한 자리다.
- **왜 문제인가**: `core/ui/` 의 공용 컴포넌트라 파급이 가장 넓다. 그리고 `AppActionDone` 은 액션 버튼(`labelLarge` 15)과 **같은 자리에 교대로 놓이는 표시**인데(같은 파일 주석 *"같은 자리의 두 상태"*), 글자 크기만 1px 다르면 기록 확정 순간 그 자리가 미세하게 흔들린다. 또 `AppSpacing` 을 우회한 숫자와 마찬가지로, 나중에 라벨 스케일을 조정할 때 이 한 줄만 따라오지 않는다.
- **제안**: `fontSize: 14` 를 지운다(= `labelLarge` 15 그대로). 112dp 액션 열에서 `✓ 완료` 가 넘친다면 폭 문제이므로 `RosterStudentTile._CompactButtons`(같은 문제를 좌우 패딩 축소로 이미 해결했다)와 같은 방식으로 풀거나, `labelMedium`(12) 슬롯으로 내린다. 어느 쪽이든 **스케일 안의 값**이어야 한다.

### M2. 같은 성격의 카드가 반경 12 와 20 을 섞어 쓴다

- **위치**:
  - `lib/features/rideevent/presentation/screen/driver_roster_screen.dart:193` — `_ProgressHeader`, `radiusMd`(12)
  - `lib/features/routing/presentation/screen/driver_route_screen.dart:192` — `_NextStopCard`, `radiusMd`(12)
  - 대조군: `lib/features/rideevent/presentation/widget/drive_start_view.dart:136` — `_BusCard`, `radiusLg`(20)
- **위반**: §3.2 — `radiusMd`(12)는 **버튼·입력·행**, `radiusLg`(20)는 **카드·시트**. C-8 Medium 4번.
- **근거**: 세 위젯의 구조가 사실상 동일하다 — 화면 상단/지도 위에 단독으로 놓이는 전폭 컨테이너, `surface`계 채움 + `outlineVariant` 1px 테두리 + `EdgeInsets.all(AppSpacing.md)`. 목록의 행도 아니고 버튼도 아니다. `_NextStopCard` 는 클래스 이름과 주석("지도 위에 떠 있는 '다음 정차' 카드")이 스스로 카드라고 밝힌다.
- **왜 문제인가**: §3.2 는 반경을 **모양이 아니라 용도**로 배정했다("값 동일, **용도가 바뀐다**"). 용도가 흔들리면 반경이 위계 신호로 작동하지 않는다 — 지금 기사 앱에서는 운행 시작 화면의 요약 카드(20)와 명단 화면의 요약 카드(12)가 다른 모서리를 갖고, 반대로 명단 요약 카드(12)와 학생 행(12, §5.2 가 지정한 정상값)이 같은 모서리를 갖는다. 카드와 행이 같아 보이는 게 이 규칙이 막으려던 것이다.
- **판단 주의**: `RosterStudentTile`(12)·`RouteStopTile`(12)은 §5.2 가 명시한 값이라 **정상**이다. 각종 안내 배너(`_GateNotice`·`_ProposalNotice`·`ErrorBanner` 등)가 12 인 것도 §3.2 가 배너 반경을 정의하지 않아 판단 근거가 없으므로 지적하지 않았다.
- **제안**: `_ProgressHeader` 와 `_NextStopCard` 를 `AppSpacing.radiusLg` 로 올린다. 겸해서 `DESIGN_SYSTEM.md` §3.2 에 **배너·안내 박스의 반경**을 한 줄 추가하면 다음 화면에서 같은 판단을 반복하지 않는다(현재 코드는 사실상 12 로 합의돼 있으므로 그대로 문서화하면 된다).

### M3. 노선 목록 필터 `ChoiceChip` 의 시각 높이가 32dp 다

- **위치**: `lib/features/routing/presentation/screen/admin_route_list_screen.dart:150-165`
- **위반**: §3.3 — 탭 가능한 요소의 최소 높이 48dp. M3 `ChoiceChip` 기본 시각 높이는 32dp 다.
- **근거 / 정확한 사실**: 실측 결과 `chip.dart:1490-1498` 에서 `ThemeData.materialTapTargetSize` 기본값 `padded` 에 따라 `kMinInteractiveDimension`(48) 제약이 붙는다 — **히트 영역은 48dp 로 충족된다.** 보이는 높이만 32 다. 그래서 H2 보다 한 단 낮게 잡았다(§3.3 이 40 을 명시적으로 금지한 것과 달리, 칩 높이에 대해서는 문서에 직접 근거가 없다).
- **왜 문제인가**: 이 패널에서 48 미만으로 그려지는 유일한 대화형 요소다. 그리고 관리자 화면 안에서도 어긋난다 — 같은 화면의 새로고침 `IconButton` 은 테마로 48, 배차 화면의 확정 버튼은 56 인데 버스 필터만 32 다. §10 이 *"데스크톱 전용으로 새로 만드는 건 행 밀도뿐"* 이라고 한 범위를 넘어 대화형 요소의 크기를 줄인 셈이다.
- **제안**: 두 갈래 중 하나. (a) `app_theme.dart` 에 `chipTheme` 을 추가해 `padding`·`labelStyle` 로 48 을 맞춘다(전역 보장, H2 제안과 묶으면 좋다). (b) 규칙을 명확히 하고 싶다면 `DESIGN_SYSTEM.md` §3.3 에 "읽기 전용 칩(§5.1 `AppStatusChip`)은 터치 최소값 대상이 아니고, 선택 칩은 대상이다"를 한 줄 넣는다. 현재 문서는 이 구분을 하지 않아 판단이 갈릴 수밖에 없다.

### M4·M5 — 지도(`core/map/impl/`)

> **범위 주의**: C-8 은 검사 대상을 `presentation/`·`core/ui/`·`app/theme/`·`app/shell/` 로 한정했고 `core/map/impl/` 은 여기 없다. 다만 `DESIGN_SYSTEM.md` §5.3 의 제목이 *"지도(`MapViewAdapter` **포트 뒤**)"* 로 이 파일을 직접 겨냥하고 있고, 팀 리드가 지도 배경을 명시적으로 지목했으므로 §5.3 근거로 보고한다. 범위 조정은 리드 판단에 맡긴다.

### M4. 지도 마커가 §5.3 이 지정하지 않은 역할색을 쓰고, 다음 정차/예정을 구분하지 않는다

- **위치**: `lib/core/map/impl/flutter_map_adapter.dart:113-144`, `:79-83`
- **위반**:

| 요소 | §5.3 규정 | 구현 |
|---|---|---|
| 다음 정차 마커 | 34 원형 **채움** `primary`/`onPrimary` + `다음 정차` 라벨 칩 | `MapMarkerKind.stop` 하나로 통합, `scheme.secondary` |
| 예정 정차 마커 | 34 **테두리만** — `surface` 바탕 + 3px `primary` 테두리 | 위와 동일(구분 없음) |
| 출발/도착지(학원) | 36 사각 radius 10, `onSurface` 바탕 | 40 원형, `scheme.tertiary` |
| 경로선 | 굵기 **9** | `strokeWidth: 5` |
| 지나온 경로 | `onPrimaryContainer` 35% 불투명 | 미구현 |

- **근거**: §5.3 표. 더불어 §1 머리말 — *"새 화면에서 새 hex 를 만들지 않는다. 아래 역할 중 하나를 고른다"* — 인데 `secondary`·`tertiary` 는 §1.1·§1.3 어느 표에도 없는 역할이다. 즉 시드에서 자동 파생될 뿐 디자인 시스템이 의미를 부여한 적 없는 색이 지도의 주요 신호로 쓰이고 있다.
- **왜 문제인가**: 지도의 존재 이유가 "다음에 어디로 가는가"인데(§5.3 이 다음 정차 마커만 채움으로 둔 이유), 모든 정차가 같은 색이라 지도만 보고는 순서를 읽을 수 없다. 목록(`RouteStopTile`)은 다음 정차를 제대로 강조하고 있어서, **같은 정보를 목록은 구분하고 지도는 구분하지 않는 어긋남**이 생겼다. `driver_route_screen.dart:62` 주석이 *"순번 원형 — 지도 마커의 숫자와 같은 값이라 서로 대응시켜 볼 수 있다"* 고 적었지만 색 대응은 끊겨 있다.
- **제안**: `MapMarkerKind` 에 `nextStop` 을 추가하고(포트 변경) `_MarkerPin` 의 색을 §5.3 표대로 `primary`/`surface`+`primary` 테두리/`onSurface` 로 바꾼다. 포트 확장이 이번 스코프를 넘는다면 최소한 **`secondary`·`tertiary` 를 §1 이 정의한 역할색으로 교체**하는 것만이라도 분리 처리할 수 있다. `strokeWidth: 5 → 9` 는 한 줄이다.

### M5. 지도 마커 라벨이 `TextStyle` 을 직접 만든다

- **위치**: `lib/core/map/impl/flutter_map_adapter.dart:131-137`, `:156-158`

```dart
Text(spec.label ?? '', style: TextStyle(color: scheme.onSecondary, fontWeight: FontWeight.bold)),
...
DefaultTextStyle.merge(style: TextStyle(color: foreground), child: content),
```

- **위반**: §7-2 — `textTheme` 슬롯을 거치지 않고 `TextStyle` 을 새로 만든다. 검사 범위 안에서는 이런 코드가 0건인데 지도에만 남아 있다.
- **왜 문제인가**: `fontSize` 를 주지 않아 정차 번호 글자 크기가 **주변 `DefaultTextStyle` 에 따라 달라진다** — 즉 크기가 정의돼 있지 않다. §5.3 이 마커에 숫자를 넣기로 한 이유가 "색이 안 읽혀도 숫자는 읽힌다"인데, 그 숫자의 크기가 미정이면 근거가 약해진다. 목록의 순번 배지는 `labelLarge` + `tabularFigures` 로 제대로 지정돼 있어(`route_stop_tile.dart:73-78`) 여기서도 같은 슬롯을 쓰면 된다.
- **제안**: `Theme.of(context).textTheme.labelLarge?.copyWith(color: …, fontFeatures: const [FontFeature.tabularFigures()])` 로 바꾼다.

---

## Low

### L1. ETA 문구가 §7-8 이 규정한 문구와 다르다

- **위치**: `lib/features/routing/domain/route_plan.dart:155-160` (표기는 `route_stop_tile.dart:112`, `driver_route_screen.dart:233` 에서 소비)

```dart
String get etaLabel {
  if (eta.inSeconds <= 0) return '출발';
  final minutes = (eta.inSeconds / 60).round();
  return minutes < 1 ? '곧 도착' : '$minutes분 후';
}
```

- **판정**: **C-8 Medium 6번(`etaSeconds` 초 노출)은 위반이 아니다** — 초는 어디에도 노출되지 않고 변환도 도메인 한 곳에 모여 있다. 다만 §7-8 이 지정한 **문구 자체**가 다르다: 규정은 `30초 이하 → 지금`, `그 외 → 약 N분 후`. 구현은 `곧 도착` / `N분 후` / `출발`(0초)이다.
- **왜 문제인가(작다)**: `약` 이 빠지면 계획 ETA 가 실측처럼 읽힌다. 지시서 §7 이 *"계획 ETA만 있고 '실제 도착 시각'은 별도로 없다"* 며 정차별 도착 실적을 금지한 것과 같은 맥락이라, `약` 은 단순 수사가 아니라 데이터의 성격 표시다.
- **범위 주의**: `domain/` 은 C-8 검사 대상 밖이다. 사용자에게 보이는 문자열이 거기 있어 보고하지만, 순위는 가장 낮다.
- **제안**: 문구를 `지금` / `약 N분 후` 로 맞추거나, `DESIGN_SYSTEM.md` §7-8 을 현재 문구(`곧 도착`·`출발` 포함, 0초 케이스가 있으므로 구현이 더 완전하다)로 갱신한다. **문서 갱신 쪽을 권한다** — 구현이 규정보다 케이스를 하나 더 다루고 있고, `약` 만 추가하면 된다.

### L2. `_RouteSummary` 의 4열 고정 `Row` 는 200% 확대에서 잘린다

- **위치**: `lib/features/routing/presentation/screen/driver_route_screen.dart:343-357` (`_Metric` 은 `:370`)
- **위반 후보**: §7-5 / C-8 Low 3번 — *"`Row` 고정폭 때문에 텍스트 200% 확대에서 깨짐"*.
- **근거(계산)**: 기사 화면은 `forceCompact` 라 폰 폭(412dp 기준)에서 그려진다. `_StopSheet` 가 좌우 `AppSpacing.md` 를 먹어 380, `AppSpacing.sm` 간격 3개를 빼면 356, 4등분하면 89, `_Metric` 내부 패딩(`smd` 좌우)을 빼면 **칸당 약 65dp**. 여기에 `titleSmall`(15) 값이 200% 로 30px 가 되면 `distanceLabel` 의 `12.4km`(공백 없는 6자, `route_plan.dart:67-69`)나 `durationLabel` 의 `약 1시간 5분`(`:72-77`)은 줄바꿈 지점이 없어 **가로로 넘쳐 잘린다**.
- **왜 문제인가**: 잘리는 값이 거리·소요시간이라 안전에 직결되진 않는다. 그래서 Low 다. 다만 같은 화면·같은 팀이 만든 `RouteStopTile:95` 는 태그를 `Wrap` 으로 처리하며 *"글자 200% 확대에서도 태그가 밀려나지 않게"* 라고 주석까지 달았다 — **한 파일 안에서 규칙 적용이 갈렸다.**
- **제안**: `_RouteSummary` 의 `Row` 를 `Wrap`(`spacing: AppSpacing.sm`)으로 바꾸고 `_Metric` 의 `Expanded` 를 제거하면 확대 시 2×2 로 접힌다. 또는 `RosterStudentTile:36` 이 쓴 `_stackAboveTextScale` 방식(`MediaQuery.textScalerOf` 임계값으로 세로 전환)을 그대로 재사용한다 — 이미 이 저장소 안에 검증된 패턴이 있다.

### L3. 간격 토큰을 반경 자리에 쓴다

- **위치**: `lib/features/rideevent/presentation/screen/driver_roster_screen.dart:229`

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(AppSpacing.xs),   // 4
  child: LinearProgressIndicator(...),
)
```

- **위반**: §3.2 의 반경 토큰은 `radiusXs`(6)·`radiusSm`(8)·`radiusMd`(12)·`radiusLg`(20) 네 개뿐이고 4 는 없다. 숫자 리터럴은 아니지만 **간격 스케일(`xs`)을 반경 스케일로 빌려 쓴** 것이라 §7-6("`AppSpacing` 경유")의 문자만 만족한다.
- **왜 문제인가(작다)**: 반경 스케일을 조정할 때 이 자리가 따라오지 않는다. 진행률 바 하나라 시각적 영향은 없다.
- **제안**: 진행률 바 끝을 완전히 둥글게 하려면 `StadiumBorder` 성격이므로 `BorderRadius.circular(AppSpacing.radiusXs)`(6) 로 올리거나, `AppSpacing` 에 진행률용 토큰을 만들지 말고 §3.2 의 `(full)` 규정대로 처리한다. 참고로 같은 파일 `:232` 의 `minHeight: AppSpacing.sm` 은 **크기**를 간격 토큰으로 쓴 것이라 같은 성격이지만, 4dp 스케일 안의 값이고 §3 이 크기 토큰을 따로 두지 않아 지적하지 않았다.

### L4. 노선 목록 빈 상태에 "다음 행동" 버튼이 없다

- **위치**: `lib/features/routing/presentation/screen/admin_route_list_screen.dart:117-121`

```dart
EmptyView(
  icon: Icons.route_outlined,
  title: '아직 만들어진 노선이 없습니다',
  description: '배차 화면에서 제안을 받고 확정하면 이곳에 노선이 쌓입니다.',
)   // ← action 없음
```

- **위반 후보**: §6 / C-8 Low 2번 — *"빈 상태에 '다음 행동' 버튼이 없음"*. §5.1 `EmptyView` 명세도 *"+ **다음 행동 버튼**"* 을 포함한다.
- **근거**: 설명 문구가 이미 "배차 화면으로 가라"고 지목하고 있고, **그 이동은 이 앱 안에서 가능하다**(`AppRoutes` 에 배차 경로가 있고, 반대 방향 링크는 `admin_dispatch_screen.dart:370-374`·`:432-436` 에 실제로 버튼으로 구현돼 있다). `EmptyView` 주석이 *"`action` 은 그 행동을 화면 안에서 바로 할 수 있을 때만 준다"* 고 한 조건을 충족한다.
- **왜 문제인가(작다)**: 관리자가 좌측 패널에서 막혀 상단 탐색으로 되돌아가야 한다. 배차 → 노선 방향에는 버튼이 있는데 노선 → 배차 방향에만 없어 **왕복 동선이 한쪽만 뚫려 있다.**
- **제안**: `action: AppActionButton(label: '배차 화면으로', tone: AppTone.primary, outlined: true, onPressed: () => context.go(AppRoutes.adminDispatch))` 를 붙인다.
- **같이 검토할 것(지적은 아님)**: `admin_dispatch_screen.dart:65` "아직 받은 제안이 없습니다"는 `제안 받기` 버튼이 바로 위 헤더에 상시 노출돼 있어 버튼 중복이 오히려 혼란이다 — **현 상태가 맞다.** `driver_roster_screen.dart:40`·`:111`, `admin_monitor_screen.dart:163`·`:185` 의 빈 상태들은 사용자가 화면 안에서 할 수 있는 행동이 없어(관리자 요청 대기 / 기사 앱 설정) `action` 없는 게 맞다.

---

## 위반 아님으로 판단한 것

후보로 올라왔지만 문서 근거를 대조한 결과 정상이라고 판단한 것들. 다음 감사에서 중복 조사하지 않도록 근거를 남긴다.

**§0-1 색만으로 상태 구분 — 위반 0건.** 상태를 내는 모든 자리가 색+아이콘+라벨 3중이다. `AppStatusChip` 이 `icon`·`label` 을 **필수 인자**로 받아 규칙을 타입으로 강제하고 있고(`app_status_chip.dart:15-20`), `ConnectionStatusChip`·`MonitoredBusTile`·`RoutePlanStatusChip`·`_DirectionCard`(선택 여부를 `check_circle`/`radio_button_unchecked` 아이콘으로도 표기) 전부 따랐다.

**§0-2 낙관적 UI — 위반 0건.** 화면뿐 아니라 컨트롤러까지 확인했다. `driver_roster_controller.dart:95-117` 은 전송 시작 시 `pending` 집합에만 넣고 상태는 건드리지 않으며, 서버 응답 `RideEvent.type` 으로만 전이시킨다. 화면 쪽도 §4.2 3단계를 그대로 구현했다 — 전송 중 칩은 이전 상태 유지 + `전송 중` 스피너, 액션 버튼은 **사라진다**(`roster_student_tile.dart:319`, 연타 방지), 실패 시 `✕ 전송 실패` + `error` 테두리 + `다시 시도`.

**§7-3 `RideStatusChip` 재구현 — 위반 0건.** §4 라벨 4종(`대기`·`승차 완료`·`하차 완료`·`보호자 인계 완료`)은 `roster_student.dart:10-13` 의 `RideStatus` enum에만 존재하고, 화면에서 이 문자열을 다시 적은 곳이 없다. `end_drive_sheet.dart:280`(잔류 학생 행)도 `RideStatusChip` 을 재사용한다.

**`RoutePlanStatusChip` 은 §7-3 위반이 아니다.** `route_plan_card.dart:108-127` 이 상태 칩을 새로 만드는 것처럼 보이지만, 대상이 **노선 계획 승인 단계**(draft/recommended/approved/published)로 §4 승하차 계약과 무관한 별개 도메인이다. 게다가 `AppStatusChip` 을 톤 매핑해 호출하는 §5.2 `RideStatusChip` 과 동일한 구조이고, 목록 카드와 상세 헤더가 같은 위젯을 공유해 오히려 규칙을 지켰다.

**아이콘·마커·애니메이션 크기.** `size: 16/18/20/24/28`, 마커·아바타 지름 `32/34/36/40/44`, `Duration(1400ms)`·`1800ms` — §5 가 명시했거나 간격 토큰의 대상이 아니다. 지시대로 올리지 않았다. 버튼·라벨 안의 스피너 크기(`app_action_button.dart:48-52` 의 18, `roster_student_tile.dart:247-251` 의 14)도 같은 성격으로 본다.

**지도 마커(40dp)의 탭.** `flutter_map_adapter.dart:162-163` 의 `GestureDetector` 는 40dp 마커 위에 얹혀 48 미만이다. 다만 리드 지시가 마커 지름을 위반으로 올리지 말라고 명시했고 §5.3 이 마커 크기를 직접 정했으므로 지적하지 않는다. **한 줄만 남긴다** — 지도 마커를 "탭 가능한 요소"로 볼지 §3.3 에 예외 문구가 없어 판단 근거가 비어 있다. 규칙을 정할 거리는 된다.

**지도 배경에 표면색 재사용 — 위반 0건.** §1.3 의 핵심 금지사항은 지켜졌다. `route_plan_map.dart:66` 과 `admin_monitor_screen.dart:159` 둘 다 `context.appColors.mapBase` 를 쓰고 주석까지 같은 근거를 댄다. 실지도는 OSM 타일이라 `mapBase`/`mapLine` 이 적용되지 않지만, 이는 §5.3 이 전제한 어댑터 구현 선택이지 표면색 재사용이 아니다. `app_shell.dart:115` 의 `surfaceContainerHighest` 는 지도가 아니라 데스크톱 폰 프레임 배경이다.

**`Colors.transparent` / `Colors.black26`.** `monitored_bus_tile.dart:75` 의 `Colors.transparent` 는 hex 리터럴이 아니라 "칠하지 않음"의 표준 표기이며 `app_theme.dart` 도 `surfaceTintColor` 에 같은 값을 쓴다. `flutter_map_adapter.dart:152` 의 `Colors.black26` 그림자는 §3.4·§5.3 이 *"그림자는 지도 위 마커에만 — `0 2px 8px rgba(0,0,0,.35)`"* 로 **역할색 체계 밖의 값을 직접 지정**했으므로 토큰 우회가 아니다(수치가 `.26`/blur 4 로 조금 다르지만 육안 판단 영역이라 지적하지 않는다).

**전체화면 스피너.** C-8 Low 1번 후보로 훑었으나 데이터 화면은 전부 `AsyncSection` + `SkeletonList` 를 쓴다(6개 화면 확인). 남은 `LoadingView`(스피너) 사용처는 `end_drive_sheet.dart:71` 한 곳인데, 시트 안에서 종료 버튼이 왜 잠겼는지 알리는 **짧은 확인 대기**이지 화면 로딩이 아니다. `AppActionButton(busy:)` 의 인디케이터도 §6 이 명시한 "동작 진행 표시"라 정상이다.

**폼·버튼 터치 크기.** `app_theme.dart:96-123` 이 `inputDecorationTheme`·`filledButtonTheme`·`outlinedButtonTheme`·`textButtonTheme`·`iconButtonTheme` 다섯 곳에 48dp 를 전역 보장한다. 개별 `TextButton`/`IconButton`/`FilledButton.icon` 은 전부 여기에 걸린다. `Switch`(`driver_location_card.dart:95`)와 `PopupMenuItem`(`app_shell.dart:160`)은 프레임워크가 `kMinInteractiveDimension`(48)을 보장한다. `NavigationBar` 는 테마에서 `height: 72`.

**레이아웃 폭 숫자.** `login_screen.dart:66` 의 `maxWidth: 380`, `_sidePanelWidth 320`·`_listPaneWidth 380`·`_maxContentWidth 880`·`_mapPreviewHeight 320` 등 — §7-6 이 금지한 것은 **간격·반경**이고 레이아웃 분기 폭은 `AppBreakpoints` 가 담당하는 별개 축이다. 스켈레톤 자리표시자 높이(`itemHeight: 96`·`header: 200` 등)도 "실제 콘텐츠 높이의 근사값"이라 토큰화 대상이 아니다. 다만 `login_screen.dart:66` 만 인라인 숫자이고 나머지는 명명 상수인 점은 취향 차이라 지적하지 않는다.

**§8 "구현하지 않는 것".** 학생 사진·학부모 연락처·학생 실시간 위치·정차별 실제 도착 시각·QR/NFC·좌석도·통계·채팅 — 전부 코드에 없다. 이니셜 원형(`roster_student_tile.dart:132-161`, `end_drive_sheet.dart:226`)까지가 한계라는 §8 규정도 지켜졌다. **없는 게 정상이므로 지적 대상이 아니다.**

**`OfflineBanner` 문구.** §8 마지막 문단이 재전송 큐가 없는 동안 시안 문구(`기록은 저장 후 재전송됩니다`)를 쓰면 거짓말이 된다고 못 박았고, `offline_banner.dart:18` 이 규정된 대체 문구를 정확히 쓴다.

**타이포 슬롯.** §2.1 매핑 8단이 `app_typography.dart` 에 그대로 들어갔고, `bodyMedium` 을 15 로 올린 것도 §2.1 의 명시적 의도다. Mono 역할은 `FontFeature.tabularFigures()` 로 대체(§2.2)했고 시각·좌표·거리·순번 표기가 전부 이를 경유한다.
