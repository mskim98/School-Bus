# 통원버스 MVP — 프론트엔드 (Next.js)

학생·학부모·버스기사 3개 모바일 화면을 **가로로 나란히** 띄워, 하나의 Mock 위치 시뮬레이션으로 실시간 연동해 보여주는 데모.

## 다시 켜서 작업하기 (Resume)

```bash
cd frontend
npm install        # 최초 1회 (이미 설치돼 있으면 생략 가능)
npm run dev        # http://localhost:3000 접속
```

- 종료: 터미널에서 `Ctrl + C`
- 프로덕션 빌드 확인: `npm run build`

### 네이버 지도 키
- `frontend/.env.local` 에 `NEXT_PUBLIC_NAVER_MAP_ID=발급받은Client_ID` 가 들어 있어야 실제 지도가 뜬다.
- 키가 없거나 로드 실패 시 자동으로 SVG 지도로 폴백되므로 앱은 항상 실행된다.
- `.env.local` 을 수정하면 **dev 서버를 재시작**해야 반영된다.
- Naver Cloud Platform 콘솔에서 Web 서비스 URL 에 `http://localhost:3000` 이 등록돼 있어야 한다.

## 현재까지 구현된 것

- **3화면 동시 데모**: `app/page.js` 가 학생/학부모/기사 모바일 뷰를 가로 배치 + 상단에 재생/일시정지/속도(1·2·4x)/리셋 컨트롤
- **Mock 위치 시뮬레이션**: `lib/simulation.js` — 하원 시나리오(도보→대기→탑승→하차) 타임라인, 분수 틱으로 부드럽게 진행. `getLocationSource()` 만 교체하면 실 GPS 전환 가능하도록 추상화
- **실제 도로 경로**: `lib/routing.js` — OSRM(무료)에서 도보/버스 구간 실제 도로 좌표를 받아 폴리라인 렌더 + 마커가 도로 위를 이동
- **네이버 지도**: `components/NaverMapView.js` — 방향 화살표(진행 방위각), 활성 마커 자동 추적, 정류장 근접 반경, 로딩 스켈레톤
- **UI**: `components/PhaseStepper.js`(4단계 진행바), 학부모 알림 토스트+배지, 단계별 상태색, 빈 상태 처리

## 파일 구조

```
frontend/
├── app/            page.js(3화면 배치+컨트롤), layout.js, globals.css
├── components/     SimulationProvider(공유상태), PhoneFrame, NaverMapView, MapView(SVG폴백),
│                   PhaseStepper, StudentApp, ParentApp, DriverApp
└── lib/            simulation.js(Mock 시뮬), routing.js(OSRM 도로경로), naverLoader.js(SDK 로더)
```

## 다음에 이어서 할 만한 것 (아직 안 한 것)

- 기능 확장: 미승차/지연 알림, 기사 수동 승하차 체크 실제 동작, 학부모 결석신고가 기사 명단에 반영
- 관리자(웹) 화면, 플랫폼 관리자 화면 (현재 3개 계층만 구현)
- 백엔드(Spring) 연동 — 현재는 전부 클라이언트 Mock. `projectInfo.md` 의 데이터 모델/시나리오 기준
- 실 GPS 전환 (`navigator.geolocation`), 도보는 자동차용 OSRM 대신 보행 라우팅으로 교체

> 서비스 전체 기획·요구사항은 저장소 루트 `projectInfo.md` 참고.
