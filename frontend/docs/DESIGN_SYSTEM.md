# 통학버스 디자인 시스템 (Flutter 적용본 v1.0)

> **문서 성격**: 화면을 그릴 때 참조하는 **단일 소스**. `FLUTTER_CODE_CONVENTIONS.md`(코드를 어떻게 쓰는가)의 짝이며 **화면을 어떻게 보이게 하는가**를 다룬다.
> Claude 가 디자인 작업마다 재참조하므로 토큰 효율을 위해 Markdown 으로 유지한다(루트 `CLAUDE.md` 예외 조항).
>
> **근거**: `docs/design/source/통학버스 디자인 시스템.dc.html` (Claude Design v0.1, 2026.07) + `docs/design/source/기사앱 MVP.dc.html`
> **요구 근거**: `docs/DESIGN_BRIEF_DRIVER_MOBILE.md` — 시안과 지시서가 충돌하면 **지시서가 이긴다**(지시서가 입력, 시안이 출력).
> **검사**: `FLUTTER_CODE_CONVENTIONS.md` §9 **C-8** 체크리스트로 `design-system-auditor` 가 훑는다.
>
> 작성일 2026-07-29

---

## 0. 이 시스템이 지키려는 것

이 앱은 **책상이 아니라 운전석에서** 쓰인다(지시서 §3). 아래 3개는 미적 판단보다 우선하며, 예뻐 보인다는 이유로 어기지 않는다.

1. **색만으로 상태를 구분하지 않는다** — 상태는 항상 `색 + 아이콘 + 텍스트 라벨` 3중 표기. 직사광선·색각 이상 대응
2. **낙관적 UI 금지** — 탭 즉시 확정 표시하지 않는다. `전송 중` → 서버 200 → 확정. 학부모 알림이 걸린 기록이라 **거짓 성공 표시가 가장 위험하다**
3. **터치 타깃 48dp 이상** — 40dp 는 금지. 주요 동작은 56dp, 화면 하단 절반에 배치(운전석 팔 도달 범위)

---

## 1. 색 — 역할로 부른다

**새 화면에서 새 hex 를 만들지 않는다.** 아래 역할 중 하나를 고른다. 위젯에 `Color(0xFF…)` 리터럴을 쓰면 그 자체로 위반이다.

### 1.1 M3 `ColorScheme` 이 커버하는 역할

| 역할 | 라이트 | 다크 | 쓰는 곳 |
|---|---|---|---|
| `primary` | `#1D4ED8` ⚠️ | `#B4C5FF` | 주요 버튼, 활성 마커, 경로선 |
| `onPrimary` | `#FFFFFF` | `#052978` ⚠️ | primary 위 텍스트·아이콘 |
| `primaryContainer` | `#DCE4FF` | `#123FA8` ⚠️ | **승차 칩**, 다음 정차 강조, 정보 배너 |
| `onPrimaryContainer` | `#001945` ⚠️ | `#DCE4FF` | 컨테이너 위 텍스트, **지나온 경로**(35% 불투명) |
| `surface` | `#FAF9FD` | `#111318` | 화면 기본 배경 |
| `surfaceContainer` | `#EEEFF5` | `#1D2025` | 카드·시트·탭바 |
| `surfaceContainerHigh` | `#E4E5ED` | `#282A30` | **스켈레톤 기준색**, 비활성 배지 |
| `onSurface` | `#1A1B20` | `#E3E2E9` | 본문 텍스트 |
| `onSurfaceVariant` | `#45464F` | `#C5C6D0` | 보조 텍스트·캡션 |
| `outline` | `#757680` | `#8F909A` | 입력 테두리 |
| `outlineVariant` | `#C5C6D0` | `#45464F` | 구분선·카드 테두리 |
| `error` | `#BA1A1A` | `#FFB4AB` | 전송 실패, 미승차, 종료 차단 |
| `errorContainer` | `#FFDAD6` | `#93000A` | 오프라인 배너, 미승차 행 배경 |
| `onErrorContainer` | `#410002` ⚠️ | `#FFDAD6` | errorContainer 위 텍스트 |

### 1.2 ⚠️ `fromSeed` 로 자동 생성되지 않는 값 — 실측 대조 결과

시안은 "시드 `#2563EB` 로 `ColorScheme.fromSeed` 하면 자동 대응된다"고 적었지만 **실제로는 일부가 다르다.** `ColorScheme.fromSeed(seedColor: Color(0xFF2563EB))` 를 Flutter 3.44.8 에서 직접 출력해 대조했다(2026-07-29):

| 역할 | `fromSeed` 결과 | 시안 값 | 판정 |
|---|---|---|---|
| light `primary` | `#4B5C92` | **`#1D4ED8`** | **오버라이드** — M3 톤 팔레트가 채도를 크게 떨어뜨린다. 직사광선 대비 요구(지시서 §3)에 미달 |
| light `onPrimaryContainer` | `#324478` | **`#001945`** | **오버라이드** — 시안이 훨씬 어둡다(대비 확보) |
| light `onErrorContainer` | `#93000A` | **`#410002`** | **오버라이드** — 위와 같은 이유 |
| dark `onPrimary` | `#1A2D60` | **`#052978`** | **오버라이드** |
| dark `primaryContainer` | `#324478` | **`#123FA8`** | **오버라이드** — 승차 칩 배경이라 눈에 띄어야 한다 |
| 나머지 surface·outline·error 계열 | — | — | **일치 또는 육안 구별 불가**(채널당 ≤4). 오버라이드하지 않는다 |

→ **결론: `fromSeed(#2563EB)` 를 베이스로 두고 위 5개만 `.copyWith()` 로 덮는다.** 팔레트를 손으로 다시 짜지 않는 이유는, 앞으로 M3 가 쓰는 다른 역할색(`secondary`·`tertiary`·`inverseSurface` 등)이 자동으로 같은 시드에서 파생돼 일관성이 유지되기 때문이다. 지시서 §9 "임의 팔레트를 늘리지 말라"도 이 방식으로 지켜진다.

### 1.3 M3 에 없어서 `ThemeExtension` 으로 추가하는 역할

`AppColors extends ThemeExtension<AppColors>` (`lib/app/theme/app_colors.dart`) 로 붙인다. **성공·경고·지도 3계열이 M3 `ColorScheme` 에 없다.**

| 역할 | 라이트 | 다크 | 쓰는 곳 |
|---|---|---|---|
| `success` | `#186B3B` | `#7FDB9C` | **인계완료 동작 버튼** |
| `onSuccess` | = `surface` | = `surface` | success 위 텍스트(시안이 `--sur` 를 씀) |
| `successContainer` | `#B8F1C7` | `#17512C` | **인계 칩**, 완료 표시, 종료 요약 |
| `onSuccessContainer` | `#00210F` | `#B8F1C7` | |
| `warning` | `#7A5900` | `#F2C14E` | 테스트 모드 등 주의 표시 |
| `onWarning` | = `surface` | = `surface` | |
| `warningContainer` | `#FFE1A3` | `#4A3600` | **하차 칩**, 하차 태그 |
| `onWarningContainer` | `#2B1D00` | `#FFDF9E` | |
| `mapBase` | `#E7EBE3` | `#22262B` | 지도 배경(타일 톤) |
| `mapLine` | `#CFD6C8` | `#343A40` | 도로망 선 |

> **지도 색은 표면색과 절대 공유하지 않는다.** 지도가 카드처럼 보이면 "여기가 지도"라는 인지가 깨진다.

읽는 법: `Theme.of(context).extension<AppColors>()!` — 편의 확장 `context.appColors` 를 `app_colors.dart` 에 같이 둔다.

---

## 2. 타이포

### 2.1 슬롯 매핑

| 시안 역할 | 시안 스펙 | Flutter `TextTheme` 슬롯 | 쓰는 곳 |
|---|---|---|---|
| Display | 700 / 40 / 1.2 | `displaySmall` | 운행 종료 요약 등 큰 수치 |
| Headline | 700 / 26 / 1.3 | `headlineSmall` | 화면 제목, "운행이 종료되었습니다" |
| Title (앱바) | 500 / 20 / 1.3 | `titleLarge` | `AppBar` 제목 |
| Body Large (학생명) | 500 / 17 / 1.3 | `titleMedium` | **학생 이름** · 정차 카드 제목 |
| — | 500 / 15 / 1.3 | `titleSmall` | 섹션 소제목 |
| Body | 400 / 15 / 1.5 | `bodyLarge` · `bodyMedium` | 본문·알림 문구 |
| — | 400 / 13 / 1.45 | `bodySmall` | 보조 텍스트(정류장·하차지) |
| Label (버튼) | 700 / 15 / 1.0 | `labelLarge` | **액션 버튼** |
| Label (칩) | 700 / 12 / 1.0 | `labelMedium` | **상태 칩** |
| Label (태그) | 700 / 11 / 1.0 | `labelSmall` | 태그·`NEW` 배지 |
| Caption | 400 / 12 / 1.4 | `bodySmall.copyWith(fontSize: 12)` | 캡션 |
| Mono (수치·시각) | Roboto Mono 400–500 | `AppTypography.mono(context)` | 시각·거리·ETA·`etaSeconds` |

**`bodyLarge` 와 `bodyMedium` 을 둘 다 15 로 둔 건 의도다.** 지시서가 "기사 앱 본문 최소 15px"를 요구하는데, 위젯이 기본으로 집어드는 슬롯이 `bodyMedium`(M3 기본 14)이라 여기를 올려두지 않으면 바닥이 뚫린다.

### 2.2 ⚠️ 폰트는 번들하지 않는다 (시안과의 의도적 차이)

시안은 본문 **Noto Sans KR**, 수치 **Roboto Mono** 를 쓴다. 우리는 **폰트 파일을 번들하지 않고 플랫폼 기본 한글 폰트에 맡긴다.**

- 한글 웹폰트는 서브셋을 해도 수 MB 다. 현재 `main.dart.js` 가 2.2MB 인데 폰트가 그보다 커진다 — 기사 앱은 차 안 LTE 환경이 전제라 초기 로딩이 곧 사용성이다
- `google_fonts` 패키지는 런타임에 Google CDN 을 때린다. nginx 단일 진입점 구성(`FLUTTER_FRONTEND_PLAN.md` §5)에서 외부 의존이 하나 늘고, 오프라인에서 폰트가 깨진다
- 타이포의 실제 요구(크기·굵기·행간·최소 15px)는 폰트 파일 없이 전부 만족된다

**대신 지켜야 할 것**: Mono 역할은 폰트 대신 `FontFeature.tabularFigures()` 로 대체한다. 시각(`14:05`)·거리·인원수가 갱신될 때 자릿수가 흔들리지 않게 하는 게 Mono 를 쓴 원래 목적이기 때문이다.

> 이 결정은 되돌릴 수 있다. 브랜드 통일이 더 중요해지면 `pubspec.yaml` `fonts:` 에 서브셋 폰트를 넣고 `AppTypography` 한 곳만 고치면 된다.

---

## 3. 간격 · 반경 · 터치

### 3.1 간격 (`AppSpacing`, 4dp 배수)

| 토큰 | 값 | 쓰는 곳 |
|---|---|---|
| `xs` | 4 | 아이콘·라벨 사이 |
| `sm` | 8 | **인접 버튼·칩 간격**(오탭 방지 최소값) |
| `smd` | 12 | 행 내부 요소 ← **신규**(시안 03절) |
| `md` | 16 | 카드 패딩·화면 좌우 여백 |
| `lg` | 24 | 섹션 사이 |
| `xl` | 32 | 화면 상단 여백 |
| `xxl` | 48 | (기존 유지) |

### 3.2 반경 (`AppSpacing`)

| 토큰 | 값 | 쓰는 곳 | 기존과 차이 |
|---|---|---|---|
| `radiusXs` | 6 | 작은 태그·배지(`다음 정차`·`NEW`) | **신규** |
| `radiusSm` | **8** | 상태 칩 | 6 → 8 |
| `radiusMd` | 12 | **버튼·입력·행** | 값 동일, **용도가 바뀐다**(기존 테마는 카드에 썼다) |
| `radiusLg` | 20 | **카드·시트** | 값 동일, 용도 이동 |
| (full) | — | 아바타·정차 배지·마커 | `BoxShape.circle` / `StadiumBorder` |

### 3.3 터치 타깃

| 값 | 용도 |
|---|---|
| **48dp** | 모든 탭 가능한 요소의 **최소값**. `FilledButton` 테마에 `minimumSize: Size.fromHeight(48)` 로 전역 보장 |
| **56dp** | 주요 동작(운행 시작·운행 종료 등 화면당 1개) |
| 40dp | **금지** |

인접 버튼 사이 최소 간격 `AppSpacing.sm`(8). 기사 앱 주요 동작 버튼은 **화면 하단 절반**에 둔다.

### 3.4 고도(elevation)

카드는 **elevation 0 + `outlineVariant` 1px 테두리**다(현재 `CardThemeData` 그대로 유지). 그림자는 **지도 위 마커에만** 쓴다 — `0 2px 8px rgba(0,0,0,.35)`.

---

## 4. ★ 승하차 상태 계약 — 임의로 바꾸지 않는다

라벨 문자열·아이콘·색은 기사 앱·관리자 웹·(향후) 학부모 앱에서 **동일해야 한다**. 화면에서 새로 문자열을 짓지 않는다.

| ENUM | 아이콘 | 라벨 | 칩 배경 / 전경 | 의미 | 학부모 알림 |
|---|---|---|---|---|---|
| `WAITING` | `·` | **대기** | `surfaceContainerHigh` / `onSurfaceVariant` | 아직 승차하지 않음. 운행 시작 시 전원 기본값 | 없음 |
| `BOARDED` | `↑` | **승차 완료** | `primaryContainer` / `onPrimaryContainer` | 차량 탑승 확인. **이 상태가 남아 있으면 운행 종료 불가** | "승차했습니다" 즉시 |
| `ALIGHTED` | `↓` | **하차 완료** | `warningContainer` / `onWarningContainer` | 차량에서 내림. 하원은 인계 단계가 남음 | "하차했습니다" 즉시 |
| `HANDED` | `✓` | **보호자 인계 완료** | `successContainer` / `onSuccessContainer` | **하원 전용 최종 상태.** 등원에는 존재하지 않음 | "보호자에게 인계되었습니다" |
| (부가) `NO_SHOW` | `!` | **미승차** | `errorContainer` / `onErrorContainer` | 도착 10분 후 서버가 발행 | — |

### 4.1 상태 전이 — 역방향 없음

```
등원  대기 → 승차 → 하차
하원  대기 → 승차 → 하차 → 인계
```

잘못 기록해도 **기사 앱에 되돌리기가 없다.** 관리자만 정정할 수 있다. 그래서 §0-2(낙관적 UI 금지)와 버튼 간격 8dp 가 안전 요구사항이다.

### 4.2 전송 3단계 표기

| 단계 | 표기 |
|---|---|
| 전송 중 | 상태 칩은 **이전 상태 그대로**, 옆에 스피너 + `전송 중` 캡션. 액션 버튼은 사라진다 |
| 성공 | 칩이 새 상태로 바뀐다. 액션 자리에 `✓ 완료`(successContainer, 비대화형) |
| 실패 | **상태를 되돌리고** 행 테두리를 `error` 로. `✕ 전송 실패` 캡션 + 같은 행에 `다시 시도`(error 아웃라인 버튼) |

---

## 5. 컴포넌트

> "각 컴포넌트는 기사 앱 MVP에서 실제로 쓰이는 형태 그대로" (시안 05절). 폭 **412dp** 기준.

### 5.1 공용 (`lib/core/ui/`) — feature 를 몰라야 한다

| 위젯 | 명세 |
|---|---|
| `AppStatusChip` | 아이콘 + 라벨. `AppTone { neutral, primary, warning, success, error }` 로 배경/전경을 고른다. padding `4×12`, radius **8**, 텍스트 `labelMedium`. **읽기 전용 — 탭 동작을 붙이지 않는다** |
| `AppTag` | 작은 분류 태그(`다음 정차`·`예정`·`NEW`). padding `4×8`, radius **6**, `labelSmall`. `filled: true` 면 `AppTone.solid` 바탕 |
| `AppTone` | 의미 톤 enum + 색 해석기(`container`/`onContainer`/`solid`/`onSolid`). M3 `ColorScheme` 과 `AppColors` 가 반씩 갖고 있는 걸 여기서 합친다. **위젯은 톤만 고르고 색은 고르지 않는다** |
| `AppActionButton` | 최소 높이 **48**(`primaryAction: true` 면 56), radius **12**, 텍스트 `labelLarge`. `tone` + `outlined` 조합: `primary`(승차·하차) / `success`(인계완료) / `error`+`outlined`(다시 시도) / `neutral`+`outlined`(새로고침). `busy: true` 면 스피너 + **비활성**(중복 전송이 곧 사고다) |
| `AppActionDone` | 기록 확정 후 액션 자리에 남는 표시(`✓ 완료`). 비활성 회색 버튼으로 그리지 않는다 — 회색은 "지금은 못 누른다"로 읽히지만 여기 뜻은 "**끝났다**"다 |
| `SkeletonBox` · `SkeletonList` | 배경 `surfaceContainerHigh`, radius 12, 1.4s 페이드 루프(`.45 → .9 → .45`), 항목마다 **0.15s 지연 스태거** |
| `OfflineBanner` | `errorContainer` 바탕, **앱바 위 최상단 고정**. 문구 `연결이 끊겼습니다 · 기록은 저장 후 재전송됩니다`. **앱을 못 쓰게 막지 않는다** |
| `LoadingView` | 전체화면 스피너 대신 **스켈레톤** 우선. 지도는 자리를 유지한 채 로딩 |
| `EmptyView` | 원형 아이콘(48, `surfaceContainerHigh`) + 제목(`titleSmall`) + 설명(`bodySmall`) + **다음 행동 버튼**. 문구는 "데이터 없음"이 아니라 **지금 무엇을 하면 되는지** |
| `ErrorView` | 원형 아이콘(48, `errorContainer`) + **서버 문구 그대로** + `다시 시도` 버튼(primary) |

### 5.2 기사 (`features/`)

| 위젯 | 위치 | 명세 |
|---|---|---|
| **`RideStatusChip`** | `features/rideevent/presentation/widget/` | **§4 표를 코드로 옮긴 유일한 지점.** 화면에서 상태 칩을 다시 만들지 않는다. 내부는 `AppStatusChip` 을 톤 매핑해 호출 |
| `RosterStudentTile` (학생 행) | `features/rideevent/presentation/widget/` | radius 12, padding 16, gap 16, `outlineVariant` 테두리.<br>아바타 44 원형(이니셜 1자, `surfaceContainerHigh`) · 이름 `titleMedium` · 장소 `bodySmall` · 상태 칩 · 우측 액션 열 **112dp 고정**.<br>NO_SHOW: 행 배경 `errorContainer` + 테두리 `error` + 아바타도 errorContainer.<br>실패: 테두리 `error`. 완료: `opacity .75` |
| `RouteStopTile` (정차 카드) | `features/routing/presentation/widget/` | radius 12, padding 14, gap 14. 좌측 순번 배지 32 원형.<br>**다음 정차**: 카드 `primaryContainer`, 배지 `primary`, 태그 `primary`.<br>**예정**: 카드 `surfaceContainer`, 배지·태그 `surfaceContainerHigh`.<br>**완료**: 위와 같고 `opacity .6`.<br>우측에 ETA(`titleSmall`) + 진행률(`3/5명`, `bodySmall`) |
| `NotificationTile` (알림 행) | `features/notification/presentation/widget/` | 좌측 40 원형 아이콘(유형별 톤) · 유형 라벨(`bodySmall`) · `NEW` 배지(`primary` 바탕, `labelSmall`) · 문구(`bodyLarge`) · 우측 시각(mono).<br>**새 알림 행은 배경 `surfaceContainer`**, 읽은 것은 투명 |

**알림 유형별 톤**: 미승차 `error` · 근접 `primary` · 승하차 `success` · 노선 배포 `neutral`.

### 5.3 지도 (`MapViewAdapter` 포트 뒤)

| 요소 | 명세 |
|---|---|
| 경로선 | `primary`, 굵기 9, 둥근 끝/이음 |
| 지나온 경로 | `onPrimaryContainer`, **불투명도 0.35** |
| 다음 정차 마커 | 34 원형 **채움** `primary`/`onPrimary` + 옆에 `다음 정차` 라벨 칩 |
| 예정 정차 마커 | 34 원형 **테두리만** — 배경 `surface`, 3px `primary` 테두리 |
| 출발/도착지(학원) | 36 사각 radius 10, `onSurface` 바탕 |
| 버스 현재 위치 | 중앙 원(`onSurface`, 3px `surface` 테두리) + **펄스 링**(`primary` 25%, 2s `scale(1→2.4)` 페이드아웃) |
| 지도 배경 | `AppColors.mapBase` / 도로선 `AppColors.mapLine` — **표면색 재사용 금지** |

---

## 6. 로딩 · 빈 상태 · 에러 · 오프라인

모든 데이터 화면은 이 **네 상태를 전부 정의**한다. `core/ui/async_section.dart` 의 `AsyncSection<T>` 를 거치면 loading/error/data 세 갈래를 빼먹을 수 없다(§C-3).

| 상태 | 규칙 |
|---|---|
| 로딩 | 전체화면 스피너 ❌ → **스켈레톤**. 지도는 자리를 유지한 채 로딩 |
| 빈 | 아이콘 + 한 줄 설명 + **다음 행동 버튼**. 원인이 다른 빈 상태는 합치지 않는다(예 "배차된 버스 없음"=관리자에게 요청 / "배포된 노선 없음"=기다리면 됨) |
| 에러 | **서버 `message` 를 그대로** 보여준다(§7-2). 임의로 다시 쓰지 않는다. + `다시 시도` |
| 오프라인 | 상단 지속 배너. **동작을 막지 않는다** |

**버튼 안의 작은 인디케이터는 "화면 로딩"이 아니라 "동작 진행 표시"다** — 스켈레톤으로 바꾸지 않는다.

---

## 7. 구현 규칙 (시안 07절 + 우리 컨벤션)

1. 위젯에 `Color(0xFF…)` 리터럴 **금지** — `Theme.of(context).colorScheme` / `context.appColors` 경유
2. 위젯에 `TextStyle(fontSize: …)` 직접 생성 **금지** — `Theme.of(context).textTheme` 슬롯 경유
3. 상태 칩은 **`RideStatusChip` 하나로만** 렌더 — 화면별 재구현 금지
4. 터치 타깃 48dp 는 `ButtonStyle` 전역 보장 + 개별 `IconButton` 은 `constraints` 확인
5. `MediaQuery.textScalerOf` **200% 에서 학생 행이 깨지지 않아야** 한다 — `Row` 고정폭 대신 `Wrap`/`Flexible`
6. 간격·반경 숫자 리터럴 금지 — `AppSpacing` 경유
7. 라벨 문자열(§4)은 한 곳(`RideStatusChip` 의 매핑)에서만 정의
8. ETA 는 `etaSeconds` 를 **사람이 읽는 표기로 변환**한다 — 30초 이하 `지금`, 그 외 `약 N분 후`. **초를 그대로 노출하지 않는다**

---

## 8. 시안에 있어도 구현하지 않는 것

지시서 §7 이 "API 에 없다"고 못 박은 것들이다. 시안이 그렸더라도 만들지 않는다.

학생 사진/아바타 이미지(**이니셜 원형까지가 한계**) · 학부모 연락처·전화 버튼 · 학생 실시간 위치 · 정차별 실제 도착 시각 · QR/NFC · 좌석 배치도 · 주간/월간 통계 · 채팅

시안 자신도 푸터에 같은 취지를 적어 뒀다: *"학생 사진·연락처·좌석도·통계·QR은 API에 없어 시스템에도 포함하지 않았습니다."*

**시안에 있으나 우리 API 로는 아직 못 만드는 것** — 오프라인 큐잉(`기록은 저장 후 재전송됩니다`)은 현재 클라이언트에 재전송 큐가 없다. 배너 문구를 그대로 쓰면 **거짓말이 된다**. 구현 전까지는 문구를 `연결이 끊겼습니다 · 기록이 전송되지 않을 수 있습니다` 로 쓴다.

---

## 9. 시드 데이터 (시안·구현이 같이 쓰는 값)

시안은 가짜 이름을 쓰지 않고 실제 Flyway 시드를 썼다. 위젯 테스트·스크린샷도 이 값을 쓴다.

`박기사` / `3호차` `서울12가3456` `25석` / `하원 A노선` / 학생 **3명** — `김민준`(정류장 A) · `이서연`(정류장 A) · `박도윤`(정류장 B) / 출발·도착 `한빛학원`

> **3명 기준으로 자연스럽고 25명까지 늘어나도 무너지지 않아야 한다.** 20~30명을 전제로 촘촘하게 짜면 실제 화면이 텅 비어 보인다.

---

## 10. 관리자 화면은 어떻게 하는가

**공유받은 시안에 관리자 화면이 없다.**(시안 푸터: "관리자 웹의 데이터 테이블·노선 편집기 … 는 다음 버전에서 추가") 그래서 관리자 4화면(관제·배차·노선·알림)은 **위 §1~§7 토큰과 §5 컴포넌트를 데스크톱 폭으로 확장**해 적용한다.

- 색·타이포·반경·상태 계약(§4)은 **기사 앱과 동일**하게 쓴다 — 같은 상태를 두 화면이 다르게 그리면 그게 사고다
- 폭 분기는 `AppBreakpoints.compact`(720) / `expanded`(1200). 관리자는 `NavigationRail`, 기사는 `NavigationBar`(`app_shell.dart` 기존 구조 유지)
- 48dp 터치 최소값은 데스크톱에서도 유지한다(마우스라고 줄이지 않는다 — 태블릿 관제 사용을 배제하지 않았다)
- 데스크톱 전용으로 새로 만드는 건 **행 밀도(density)뿐**이다. 새 색·새 반경을 만들지 않는다

---

## 11. 관련 문서

| 문서 | 관계 |
|---|---|
| `DESIGN_BRIEF_DRIVER_MOBILE.md` | **입력**. 시안이 이걸 어겼으면 이쪽이 맞다 |
| `docs/design/source/*.dc.html` | **원본 시안**. 값 다툼이 나면 여기가 기준 |
| `FLUTTER_CODE_CONVENTIONS.md` §9 C-8 | 이 문서 준수 여부 **검사 체크리스트** |
| `DESIGN_MIGRATION_PLAN.md` | 이식 작업 진행 추적 |
| `FLUTTER_FRONTEND_PLAN.md` | 프론트 전체 계획(무엇을 만드는가) |
