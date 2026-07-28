# Claude Design 산출물 원본 (읽기 전용)

> **고치지 않는다.** 여기 있는 건 Claude Design 프로젝트에서 그대로 내려받은 시안이다.
> 우리 코드가 따르는 규칙은 원본이 아니라 **[`../../DESIGN_SYSTEM.md`](../../DESIGN_SYSTEM.md)** 에 있다.
> 원본을 고치고 싶으면 Claude Design 쪽에서 고친 뒤 다시 내려받는다.

- **출처**: `https://claude.ai/design/p/b979a5b1-223c-439b-91ef-e9f7c4f54b9b`
- **반입일**: 2026-07-29 (`DesignSync` MCP `get_file`)
- **입력 지시서**: [`../../DESIGN_BRIEF_DRIVER_MOBILE.md`](../../DESIGN_BRIEF_DRIVER_MOBILE.md) — 이 시안은 그 문서를 넣어 나온 결과물이다. 둘을 쌍으로 봐야 "왜 이렇게 생겼는지"가 추적된다

## 파일

| 파일 | 성격 | 우리가 쓰는 방식 |
|---|---|---|
| `통학버스 디자인 시스템.dc.html` | **디자인 시스템 본체** (v0.1, 2026.07). 역할색 12종 · 타이포 8단 · 간격/터치/반경 · 승하차 상태 계약 · 컴포넌트 · 로딩/빈/에러 · **Flutter ThemeData 매핑** | `DESIGN_SYSTEM.md` 의 근거. 토큰 값을 다투게 되면 이 파일이 기준 |
| `기사앱 MVP.dc.html` | **기사 앱 7화면 시안**. 라이트/다크 · 등원/하원 · 명단 3명/25명 · 상태 시나리오를 좌측 패널에서 토글하는 인터랙티브 프로토타입 | 화면 이식(D5~D7)의 레이아웃 근거 |
| `support.js` | Claude Design 캔버스 런타임 (`dc-runtime` 빌드 산출물, `// GENERATED … do not edit`) | 디자인 내용이 아니다. **두 `.dc.html` 을 브라우저에서 열어보기 위해서만** 같이 둔다 |

## 브라우저에서 보기

```bash
cd frontend/docs/design/source && python3 -m http.server 8090
# http://localhost:8090/통학버스%20디자인%20시스템.dc.html
```

`file://` 로 직접 열면 `support.js` 가 상대경로로 로드되긴 하나 폰트 CDN·모듈 로딩이 막힐 수 있어 정적 서버 경유를 권한다.

## 일부러 안 가져온 파일

`android-frame.jsx` — Claude Design 의 **범용 Android(M3) 디바이스 프레임 스타터**다. 파일 첫 줄이 스스로 `// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)` 라고 밝히고 있고, 팔레트도 Material 샘플 기본값(`#006a60` teal)이라 **우리 브랜드(`#2563EB`)와 무관**하다. 시안을 폰 모양 안에 넣어 보여주기 위한 미리보기 껍데기일 뿐이다.

우리 쪽 대응물은 이미 있다 — `lib/app/shell/app_shell.dart` 의 `forceCompact` 가 넓은 모니터에서 기사 화면을 폰 폭(`AppBreakpoints.compact`)으로 좁혀 가운데 정렬한다. 새로 만들 것이 없다.

필요해지면 언제든 다시 받을 수 있다:
```
DesignSync(method="get_file", projectId="b979a5b1-223c-439b-91ef-e9f7c4f54b9b", path="android-frame.jsx")
```
