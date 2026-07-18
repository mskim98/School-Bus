'use client';

import { PLACES } from '@/lib/simulation';

// 공유 Mock 지도. 세 앱이 동일 좌표계를 바라본다.
export default function MapView({ state, showStudent = true, showBus = true, height = 200 }) {
  const { bus, student, boarded } = state;
  const p = (v) => v; // 0~100 좌표를 viewBox 0~100 에 그대로 사용

  const busPath = `M${PLACES.busStart.x},${PLACES.busStart.y} L${PLACES.stopA.x},${PLACES.stopA.y} L${PLACES.stopB.x},${PLACES.stopB.y} L${PLACES.academy.x},${PLACES.academy.y}`;
  const walkPath = `M${PLACES.home.x},${PLACES.home.y} L${PLACES.stopA.x},${PLACES.stopA.y}`;

  const stopDots = [PLACES.stopA, PLACES.stopB];

  return (
    <div className="map" style={{ height }}>
      <svg viewBox="0 0 100 100" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
        {/* 배경 격자 */}
        <rect x="0" y="0" width="100" height="100" fill="#eef3f8" />
        {[20, 40, 60, 80].map((g) => (
          <g key={g}>
            <line x1={g} y1="0" x2={g} y2="100" stroke="#e0e7ef" strokeWidth="0.4" />
            <line x1="0" y1={g} x2="100" y2={g} stroke="#e0e7ef" strokeWidth="0.4" />
          </g>
        ))}

        {/* 도보 경로 */}
        <path d={walkPath} stroke="#94a3b8" strokeWidth="1" strokeDasharray="2 2" fill="none" />
        {/* 버스 노선 */}
        <path d={busPath} stroke="#2563eb" strokeWidth="1.6" fill="none" strokeLinejoin="round" />

        {/* 장소 마커 */}
        <PlaceMarker place={PLACES.home} color="#64748b" />
        <PlaceMarker place={PLACES.academy} color="#0f766e" />
        {stopDots.map((s) => (
          <PlaceMarker key={s.label} place={s} color="#2563eb" small />
        ))}

        {/* 버스 마커 */}
        {showBus && (
          <g>
            <circle cx={p(bus.x)} cy={p(bus.y)} r="3.4" fill="#2563eb" stroke="#fff" strokeWidth="0.8" />
            <text x={p(bus.x)} y={p(bus.y) + 1.3} fontSize="3.6" textAnchor="middle" fill="#fff">🚌</text>
          </g>
        )}

        {/* 학생 마커 (탑승 중이면 버스와 겹치므로 살짝 오프셋) */}
        {showStudent && (
          <g>
            <circle
              cx={p(student.x) + (boarded ? 4 : 0)}
              cy={p(student.y) - (boarded ? 4 : 0)}
              r="2.6"
              fill="#f97316"
              stroke="#fff"
              strokeWidth="0.7"
            />
          </g>
        )}
      </svg>
    </div>
  );
}

function PlaceMarker({ place, color, small }) {
  const r = small ? 1.8 : 2.4;
  return (
    <g>
      <circle cx={place.x} cy={place.y} r={r} fill="#fff" stroke={color} strokeWidth="1" />
      <circle cx={place.x} cy={place.y} r={r / 2.5} fill={color} />
      <text x={place.x} y={place.y - r - 1} fontSize="3" textAnchor="middle" fill="#475569">
        {place.label}
      </text>
    </g>
  );
}
