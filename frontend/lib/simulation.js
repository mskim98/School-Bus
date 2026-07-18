import { pointAlong } from './routing';

// Mock 위치 시뮬레이터 (projectInfo 4.1)
// 실제 GPS 연동 시 getLocationSource() 만 교체하면 되도록 위치 소스를 추상화한다.
// 좌표계: 0~100 정규화 평면 (SVG 지도와 1:1 매핑)

// x/y = SVG 지도용 정규화 좌표(0~100), lat/lng = 실제 지도(네이버)용 위경도(서울 강남 일대)
export const PLACES = {
  home: { x: 14, y: 82, lat: 37.4979, lng: 127.0246, label: '집' },
  stopA: { x: 36, y: 64, lat: 37.5010, lng: 127.0275, label: '정류장 A' },
  stopB: { x: 60, y: 46, lat: 37.5045, lng: 127.0310, label: '정류장 B' },
  academy: { x: 86, y: 18, lat: 37.5075, lng: 127.0355, label: '학원' },
  busStart: { x: 8, y: 42, lat: 37.4958, lng: 127.0225, label: '차고지' },
};

// 지도 초기 중심(강남역 부근)
export const MAP_CENTER = { lat: 37.5020, lng: 127.0290 };

// 시뮬레이션 총 길이(틱). 1틱 ≈ 실시간 1스텝
export const TOTAL_TICKS = 42;

// 주요 이벤트 타임라인 — 승하차 체크/알림은 Mock 여부와 무관하게 실제 로직
export const EVENTS = [
  { tick: 15, type: 'approach', place: 'stopA', to: ['student', 'parent'],
    text: '5분 후 정류장 A에 버스가 도착합니다' },
  { tick: 18, type: 'board', place: 'stopA', to: ['parent'],
    text: '김민준 학생이 승차했습니다 (정류장 A)' },
  { tick: 36, type: 'approach', place: 'academy', to: ['student', 'parent'],
    text: '5분 후 학원에 도착합니다' },
  { tick: 40, type: 'alight', place: 'academy', to: ['parent'],
    text: '김민준 학생이 하차했습니다 (학원 도착)' },
];

const BOARD_TICK = 18;
const ALIGHT_TICK = 40;

// 담당 학생 명단 (multi-tenant: academy = '한빛학원')
// live = 실시간 시뮬 연동 학생, 나머지는 기사 수동확인(체크인)으로 상태 결정
export const STUDENTS = [
  { id: 'kim', name: '김민준', stop: 'stopA', live: true },
  { id: 'lee', name: '이서연', stop: 'stopA' },
  { id: 'park', name: '박도윤', stop: 'stopB', preAbsent: true },
];

// 정류장별 버스 도착 틱 (미탑승 판정 기준)
export const STOP_ARRIVAL = { stopA: BOARD_TICK, stopB: 30 };
// 도착 후 이 틱까지 확인 없으면 '미탑승'으로 판정
const BOARD_WINDOW = 5;

// 학생별 상태를 순수 계산 — checkins: { [id]: 'boarded' | 'absent' } (기사 수동확인)
// absences: 학부모 결석 신고로 스킵된 학생 id 배열 (기능7·10 명단 자동 갱신)
export function computePassengers(t, checkins = {}, absences = []) {
  return STUDENTS.map((s) => {
    const arrive = STOP_ARRIVAL[s.stop];
    // 결석 신고된 학생은 live 여부와 무관하게 노선에서 스킵
    if (absences.includes(s.id)) return { ...s, arrive, status: 'absent' };
    let status;
    if (s.live) {
      status = t >= ALIGHT_TICK ? 'alighted' : t >= BOARD_TICK ? 'boarded' : 'waiting';
    } else if (s.preAbsent) {
      status = 'absent';
    } else {
      const ov = checkins[s.id];
      if (ov === 'boarded') status = t >= ALIGHT_TICK ? 'alighted' : 'boarded';
      else if (ov === 'absent') status = 'absent';
      else if (t > arrive + BOARD_WINDOW) status = 'noshow'; // 확인 window 초과 → 미탑승
      else if (t >= arrive) status = 'pending'; // 버스 도착, 기사 확인 대기
      else status = 'waiting';
    }
    return { ...s, arrive, status };
  });
}

function lerp(a, b, t) {
  const k = Math.max(0, Math.min(1, t));
  return {
    x: a.x + (b.x - a.x) * k,
    y: a.y + (b.y - a.y) * k,
    lat: a.lat + (b.lat - a.lat) * k,
    lng: a.lng + (b.lng - a.lng) * k,
  };
}

// 버스 경로: 차고지 → 정류장 A(18틱) → 정류장 B(30틱) → 학원(40틱)
function busPosition(t) {
  if (t <= BOARD_TICK) return lerp(PLACES.busStart, PLACES.stopA, t / BOARD_TICK);
  if (t <= 30) return lerp(PLACES.stopA, PLACES.stopB, (t - BOARD_TICK) / (30 - BOARD_TICK));
  if (t <= ALIGHT_TICK) return lerp(PLACES.stopB, PLACES.academy, (t - 30) / (ALIGHT_TICK - 30));
  return PLACES.academy;
}

// 학생 위치: 집 → 정류장 A(12틱 도보) → 대기 → 승차 후 버스와 동일
function studentPosition(t) {
  if (t <= 12) return lerp(PLACES.home, PLACES.stopA, t / 12);
  if (t <= BOARD_TICK) return PLACES.stopA; // 정류장 대기
  return busPosition(t); // 탑승 중
}

// ── 실제 도로 경로 버전 (routes 가 로드되면 lat/lng 을 도로 위 좌표로 계산) ──
function busRoad(t, routes) {
  const legs = routes.busLegs;
  if (t <= BOARD_TICK) return pointAlong(legs[0], t / BOARD_TICK);
  if (t <= 30) return pointAlong(legs[1], (t - BOARD_TICK) / (30 - BOARD_TICK));
  if (t <= ALIGHT_TICK) return pointAlong(legs[2], (t - 30) / (ALIGHT_TICK - 30));
  return { lat: PLACES.academy.lat, lng: PLACES.academy.lng };
}

function studentRoad(t, routes) {
  if (t <= 12) return pointAlong(routes.walk, t / 12); // 도보 경로 위 이동
  if (t <= BOARD_TICK) return { lat: PLACES.stopA.lat, lng: PLACES.stopA.lng };
  return busRoad(t, routes); // 탑승 후 버스 경로
}

// ── 멀티 테넌트: 여러 학원, 각 학원이 여러 버스로 승하원 운행 ──
// 한빛학원의 3호차(bus3)만 실시간 시뮬 연동, 나머지는 Mock 순환 운행.
export const TENANTS = [
  { id: 'hanbit', name: '한빛학원' },
  { id: 'gaon', name: '가온에듀' },
  { id: 'mirae', name: '미래코딩' },
];

// 학원별 버스 정의 (tenant = 소속 학원)
export const BUSES = [
  // 한빛학원 (강남 일대)
  { id: 'bus3', tenant: 'hanbit', label: '3호차', route: '하원 A노선', driver: '박기사', capacity: 25, live: true, color: '#2563eb' },
  { id: 'bus1', tenant: 'hanbit', label: '1호차', route: '하원 B노선', driver: '김기사', capacity: 25, color: '#0891b2',
    loop: [{ lat: 37.5075, lng: 127.0205 }, { lat: 37.5088, lng: 127.0240 }, { lat: 37.5098, lng: 127.0288 },
      { lat: 37.5080, lng: 127.0315 }, { lat: 37.5055, lng: 127.0335 }, { lat: 37.5038, lng: 127.0300 },
      { lat: 37.5025, lng: 127.0258 }, { lat: 37.5045, lng: 127.0220 }], period: 64, onboard: 12 },
  { id: 'bus5', tenant: 'hanbit', label: '5호차', route: '하원 C노선', driver: '이기사', capacity: 20, color: '#7c3aed',
    loop: [{ lat: 37.4988, lng: 127.0315 }, { lat: 37.4975, lng: 127.0345 }, { lat: 37.4968, lng: 127.0375 },
      { lat: 37.4990, lng: 127.0398 }, { lat: 37.5012, lng: 127.0405 }, { lat: 37.5020, lng: 127.0372 },
      { lat: 37.5022, lng: 127.0335 }, { lat: 37.5005, lng: 127.0322 }], period: 52, onboard: 8 },
  // 가온에듀 (북동쪽)
  { id: 'gaon2', tenant: 'gaon', label: '2호차', route: '가온 1노선', driver: '최기사', capacity: 25, color: '#16a34a',
    loop: [{ lat: 37.5110, lng: 127.0320 }, { lat: 37.5125, lng: 127.0358 }, { lat: 37.5135, lng: 127.0400 },
      { lat: 37.5118, lng: 127.0430 }, { lat: 37.5095, lng: 127.0445 }, { lat: 37.5080, lng: 127.0410 },
      { lat: 37.5075, lng: 127.0360 }, { lat: 37.5090, lng: 127.0335 }], period: 58, onboard: 15 },
  { id: 'gaon7', tenant: 'gaon', label: '7호차', route: '가온 2노선', driver: '정기사', capacity: 20, color: '#d97706',
    loop: [{ lat: 37.5150, lng: 127.0250 }, { lat: 37.5165, lng: 127.0290 }, { lat: 37.5170, lng: 127.0330 },
      { lat: 37.5158, lng: 127.0362 }, { lat: 37.5140, lng: 127.0380 }, { lat: 37.5125, lng: 127.0345 },
      { lat: 37.5120, lng: 127.0290 }, { lat: 37.5132, lng: 127.0262 }], period: 72, onboard: 7 },
  // 미래코딩 (남서쪽) — 1대는 운행 대기(차고지)
  { id: 'mirae4', tenant: 'mirae', label: '4호차', route: '미래 A노선', driver: '한기사', capacity: 18, color: '#db2777',
    loop: [{ lat: 37.4935, lng: 127.0205 }, { lat: 37.4922, lng: 127.0240 }, { lat: 37.4915, lng: 127.0275 },
      { lat: 37.4935, lng: 127.0302 }, { lat: 37.4955, lng: 127.0315 }, { lat: 37.4972, lng: 127.0285 },
      { lat: 37.4975, lng: 127.0240 }, { lat: 37.4958, lng: 127.0215 }], period: 48, onboard: 10 },
  { id: 'mirae9', tenant: 'mirae', label: '9호차', route: '미래 B노선', driver: '오기사', capacity: 18, color: '#64748b',
    loop: null, period: 0, onboard: 0, running: false }, // 운행 대기(차고지)
];

const DEPOT = { lat: 37.4920, lng: 127.0180 }; // 미운행 버스 차고지

// 실시간 3호차 노선(차고지→정류장A→B→학원)을 도로처럼 보이게 하는 가상 경유점
const LIVE_ROUTE = [
  { lat: 37.4958, lng: 127.0225 }, // 차고지
  { lat: 37.4978, lng: 127.0242 },
  { lat: 37.4995, lng: 127.0268 },
  { lat: 37.5010, lng: 127.0275 }, // 정류장 A
  { lat: 37.5028, lng: 127.0288 },
  { lat: 37.5045, lng: 127.0310 }, // 정류장 B
  { lat: 37.5058, lng: 127.0332 },
  { lat: 37.5075, lng: 127.0355 }, // 학원
];

// 버스별 배정 학생 수(assigned) — 정원(capacity) 대비 초과 배정 경고 판정용(기능9)
// 좌석 정원(capacity)과 노선 배정 인원(assigned)은 별개 개념 → projectInfo 6장 참조
const ASSIGNED = {
  bus3: 3, bus1: 27, bus5: 8, gaon2: 15, gaon7: 7, mirae4: 10, mirae9: 0,
}; // bus1: 25인승에 27명 배정 → 초과 경고 데모

// 학원별 fleet(한빛=admin용) 하위집합
export const FLEET = BUSES.filter((b) => b.tenant === 'hanbit');

// 닫힌 경로(loop) 위를 fraction(0~1)만큼 이동한 좌표
function alongLoop(loop, frac) {
  const n = loop.length;
  const total = frac * n;
  const i = Math.floor(total) % n;
  const k = total - Math.floor(total);
  const a = loop[i];
  const b = loop[(i + 1) % n];
  return { lat: a.lat + (b.lat - a.lat) * k, lng: a.lng + (b.lng - a.lng) * k };
}

const TENANT_NAME = Object.fromEntries(TENANTS.map((t) => [t.id, t.name]));

// 버스 1대의 현재 상태 계산 — live 버스는 실 시뮬 state 사용
function busState(b, t, liveState) {
  const assigned = ASSIGNED[b.id] ?? 0;
  const base = { id: b.id, tenant: b.tenant, tenantName: TENANT_NAME[b.tenant],
    label: b.label, route: b.route, driver: b.driver, capacity: b.capacity, live: !!b.live,
    color: b.color || '#2563eb',
    assigned, overCapacity: assigned > b.capacity }; // 배정>정원이면 초과 경고
  if (b.live) {
    // 실 노선(차고지→정류장A→B→학원) — 중간 경유점(가상 waypoint)을 넣어 도로처럼 표시
    const path = LIVE_ROUTE;
    return { ...base, lat: liveState.bus.lat, lng: liveState.bus.lng,
      onboard: liveState.onboardCount, phaseLabel: liveState.phase.label, running: !liveState.alighted, path };
  }
  if (!b.loop || b.running === false) {
    return { ...base, lat: DEPOT.lat, lng: DEPOT.lng, onboard: 0, phaseLabel: '운행 대기', running: false, path: null };
  }
  const pos = alongLoop(b.loop, (t % b.period) / b.period);
  // 순환 노선(loop) 폐곡선 경로
  const path = [...b.loop, b.loop[0]].map((p) => ({ lat: p.lat, lng: p.lng }));
  return { ...base, lat: pos.lat, lng: pos.lng, onboard: b.onboard, phaseLabel: '운행 중', running: true, path };
}

// 관리자용: 한빛학원 버스만
export function computeFleet(t, liveState) {
  return FLEET.map((b) => busState(b, t, liveState));
}

// 플랫폼 관리자용: 전체 학원의 모든 버스
export function computeAllBuses(t, liveState) {
  return BUSES.map((b) => busState(b, t, liveState));
}

// 학생/학부모용 도착 예상(ETA) — 1틱 = 1분 가정
export function etaInfo(t) {
  if (t < BOARD_TICK) return { target: PLACES.stopA.label, min: Math.max(1, Math.ceil(STOP_ARRIVAL.stopA - t)), kind: 'toStop' };
  if (t < ALIGHT_TICK) return { target: PLACES.academy.label, min: Math.max(1, Math.ceil(ALIGHT_TICK - t)), kind: 'toAcademy' };
  return null;
}

export function phaseOf(t) {
  if (t < 12) return { key: 'walking', label: '도보 이동 중', desc: '정류장 A로 이동 중' };
  if (t < BOARD_TICK) return { key: 'waiting', label: '정류장 대기 중', desc: '버스를 기다리는 중' };
  if (t < ALIGHT_TICK) return { key: 'onboard', label: '버스 탑승 중', desc: '학원으로 이동 중' };
  return { key: 'arrived', label: '하차 완료', desc: '학원에 도착했습니다' };
}

// 특정 틱에서의 전체 상태를 순수 함수로 계산 (t 만으로 재현 가능 → 되감기/리셋 안전)
export function computeState(t, routes = null, checkins = {}, absences = []) {
  const bus = { ...busPosition(t) };
  const student = { ...studentPosition(t) };
  const phase = phaseOf(t);
  const passengers = computePassengers(t, checkins, absences);
  const myAbsent = absences.includes('kim'); // 학부모 앱 자녀(김민준) 결석 여부

  // 도로 경로가 로드됐으면 지도용 lat/lng 을 도로 위 좌표로 덮어쓴다
  // (x/y 는 SVG 폴백 지도용으로 직선 값 유지)
  if (routes && routes.walk && routes.busLegs) {
    const b = busRoad(t, routes);
    const s = studentRoad(t, routes);
    if (b) { bus.lat = b.lat; bus.lng = b.lng; }
    if (s) { student.lat = s.lat; student.lng = s.lng; }
  }

  // 결석 신고 시 자녀(live) 관련 정적 이벤트(근접/승차/하차 알림)는 발생하지 않음
  const fired = (myAbsent ? [] : EVENTS).filter((e) => e.tick <= t);
  let notifications = fired.map((e, i) => ({ id: i, ...e }));

  // 미탑승 알림: 확인 window 초과 학생마다 동적 생성 (학부모·기사에 전파)
  const noShowNotis = passengers
    .filter((p) => p.status === 'noshow')
    .map((p, i) => ({
      id: 1000 + i,
      tick: p.arrive + BOARD_WINDOW,
      type: 'noshow',
      to: ['parent', 'driver', 'admin'],
      text: `⚠️ ${p.name} 학생이 ${PLACES[p.stop].label}에서 미탑승했습니다`,
    }));
  notifications = [...notifications, ...noShowNotis];

  // 안심 하차: live 학생이 학원에 하차 완료하면 사진 포함 확인 알림 (학부모)
  if (t >= ALIGHT_TICK && !myAbsent) {
    notifications.push({
      id: 2000, tick: ALIGHT_TICK, type: 'safe', to: ['parent'], photo: true,
      text: '✅ 김민준 학생이 학원에 안전하게 하차했습니다',
    });
  }
  notifications.sort((a, b) => a.tick - b.tick);

  // 승차 확인된 학생마다 승차 기록 생성 + 하차 기록
  const rideEvents = [];
  passengers.forEach((p) => {
    if (p.status === 'boarded' || p.status === 'alighted') {
      rideEvents.push({ name: p.name, type: '승차', place: PLACES[p.stop].label,
        coord: PLACES[p.stop], tick: p.arrive, live: p.live });
    }
    if (p.status === 'alighted') {
      rideEvents.push({ name: p.name, type: '하차', place: PLACES.academy.label,
        coord: PLACES.academy, tick: ALIGHT_TICK, live: p.live });
    }
  });
  rideEvents.sort((a, b) => a.tick - b.tick);

  const boarded = t >= BOARD_TICK;
  const alighted = t >= ALIGHT_TICK;
  // 현재 버스 탑승 인원 (탑승 확인됐고 아직 하차 전)
  const onboardCount = passengers.filter((p) => p.status === 'boarded').length;

  const eta = myAbsent ? null : etaInfo(t);

  return { t, bus, student, phase, notifications, rideEvents, boarded, alighted,
    passengers, onboardCount, eta, myAbsent };
}

// 시각 표기용: 08:00 기준 1틱=1분으로 가정한 Mock 시각
export function tickToClock(tick) {
  const base = 8 * 60; // 08:00
  const total = Math.floor(base + tick); // 분수 틱 절삭
  const h = String(Math.floor(total / 60)).padStart(2, '0');
  const m = String(total % 60).padStart(2, '0');
  return `${h}:${m}`;
}

// 도보 구간 남은 소요시간(분) — 정류장 도착(12틱)까지 1틱=1분 가정으로 실제 계산
// (기존 하드코딩 "약 4분"을 대체 — 기능3 도보 경로 소요시간)
export function walkRemainingMin(t) {
  if (t >= 12) return 0;
  return Math.max(1, Math.ceil(12 - t));
}

// 운행 종료 시 일일 로그 요약(기능8) — 승차/하차/미탑승/결석 집계 + 운행 시각
export function dailyLogSummary(passengers) {
  const count = (st) => passengers.filter((p) => p.status === st).length;
  const boarded = count('boarded') + count('alighted');
  return {
    boarded,
    alighted: count('alighted'),
    noshow: count('noshow'),
    absent: count('absent'),
    total: passengers.length,
    startClock: tickToClock(0),
    endClock: tickToClock(ALIGHT_TICK),
  };
}

// 승하차 기록 캘린더(기능2) — 과거 통원일 Mock 이력. 실서비스에선 RideEvent 조회로 대체.
export const RIDE_HISTORY = [
  { date: '07-10 (목)', board: '08:15 · 정류장 A', alight: '08:38 · 학원', status: 'normal' },
  { date: '07-09 (수)', board: '08:16 · 정류장 A', alight: '08:41 · 학원', status: 'late' },
  { date: '07-08 (화)', board: '결석 신고', alight: '—', status: 'absent' },
  { date: '07-07 (월)', board: '08:14 · 정류장 A', alight: '08:37 · 학원', status: 'normal' },
  { date: '07-04 (금)', board: '08:15 · 정류장 A', alight: '08:39 · 학원', status: 'normal' },
];

// 실제 GPS 전환 지점 (MVP: mock). navigator.geolocation 으로 교체 예정.
export function getLocationSource() {
  return { kind: 'mock', note: 'Mock 좌표 스트림 (실 GPS 연동 시 교체)' };
}
