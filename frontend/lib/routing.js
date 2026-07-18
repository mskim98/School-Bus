// 실제 도로를 따라가는 경로를 OSRM(무료 라우팅 서비스)에서 받아온다.
// 반환 좌표를 이용해 지도 폴리라인을 그리고, 마커를 그 위에서 이동시킨다.
import { PLACES } from './simulation';

const OSRM = 'https://router.project-osrm.org/route/v1';

// 한 구간(start→goal)의 도로 좌표 배열을 [{lat,lng}, ...] 로 반환
async function fetchLeg(from, to, profile = 'driving') {
  const coords = `${from.lng},${from.lat};${to.lng},${to.lat}`;
  const url = `${OSRM}/${profile}/${coords}?overview=full&geometries=geojson`;
  const res = await fetch(url);
  if (!res.ok) throw new Error('OSRM_FAIL');
  const data = await res.json();
  const line = data.routes?.[0]?.geometry?.coordinates;
  if (!line || !line.length) throw new Error('OSRM_EMPTY');
  return line.map(([lng, lat]) => ({ lat, lng }));
}

// 데모 전체 경로(도보 1구간 + 버스 3구간)를 병렬로 받아온다.
export async function fetchRoutes() {
  const [walk, leg0, leg1, leg2] = await Promise.all([
    fetchLeg(PLACES.home, PLACES.stopA),   // 도보: 집 → 정류장 A
    fetchLeg(PLACES.busStart, PLACES.stopA), // 버스: 차고지 → 정류장 A
    fetchLeg(PLACES.stopA, PLACES.stopB),    // 버스: 정류장 A → B
    fetchLeg(PLACES.stopB, PLACES.academy),  // 버스: 정류장 B → 학원
  ]);
  return { walk, busLegs: [leg0, leg1, leg2] };
}

// 경로 배열의 누적 거리(대략, 평면 근사) — pointAlong 계산용
function cumulative(route) {
  const acc = [0];
  for (let i = 1; i < route.length; i++) {
    const a = route[i - 1];
    const b = route[i];
    const dx = (b.lng - a.lng) * Math.cos((a.lat * Math.PI) / 180) * 111320;
    const dy = (b.lat - a.lat) * 110540;
    acc.push(acc[i - 1] + Math.hypot(dx, dy));
  }
  return acc;
}

// 경로 위에서 진행률 f(0~1) 에 해당하는 좌표를 보간해 반환
export function pointAlong(route, f) {
  if (!route || route.length === 0) return null;
  if (route.length === 1) return route[0];
  const acc = cumulative(route);
  const total = acc[acc.length - 1];
  const target = Math.max(0, Math.min(1, f)) * total;
  // target 이 속한 구간 탐색
  let i = 1;
  while (i < acc.length && acc[i] < target) i++;
  const a = route[i - 1];
  const b = route[i] || a;
  const segLen = acc[i] - acc[i - 1] || 1;
  const k = (target - acc[i - 1]) / segLen;
  return { lat: a.lat + (b.lat - a.lat) * k, lng: a.lng + (b.lng - a.lng) * k };
}
