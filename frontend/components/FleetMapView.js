'use client';

import { useEffect, useRef, useState } from 'react';
import { loadNaverMaps } from '@/lib/naverLoader';
import { MAP_CENTER } from '@/lib/simulation';

// 버스 마커 HTML (선택 시 강조 + 인원 배지)
function fleetBusContent(label, onboard, selected, color) {
  const bg = color || '#2563eb';
  // 선택은 색이 아닌 링/크기로 강조(노선별 고유색 유지)
  const size = selected ? 34 : 28;
  const ring = selected ? `box-shadow:0 0 0 4px ${bg}44;` : '';
  return `<div style="transform:translate(-50%,-50%);display:flex;flex-direction:column;align-items:center;gap:2px;cursor:pointer">
    <div style="position:relative;width:${size}px;height:${size}px;border-radius:50%;background:${bg};border:2px solid #fff;display:flex;align-items:center;justify-content:center;font-size:15px;${ring}box-shadow:0 2px 6px rgba(0,0,0,.4)">🚌
      ${onboard > 0 ? `<div style="position:absolute;top:-5px;right:-5px;min-width:15px;height:15px;padding:0 3px;border-radius:999px;background:#16a34a;border:1.5px solid #fff;color:#fff;font-size:9px;font-weight:700;display:flex;align-items:center;justify-content:center">${onboard}</div>` : ''}
    </div>
    <div style="background:#fff;border:1px solid ${bg};color:${bg};font-size:10px;font-weight:700;padding:1px 5px;border-radius:6px;white-space:nowrap">${label}</div>
  </div>`;
}

// SVG 폴백용: 고정 bbox 로 lat/lng → 0~100 정규화
const BBOX = { latMin: 37.489, latMax: 37.519, lngMin: 127.015, lngMax: 127.046 };
const toXY = (b) => ({
  x: ((b.lng - BBOX.lngMin) / (BBOX.lngMax - BBOX.lngMin)) * 100,
  y: (1 - (b.lat - BBOX.latMin) / (BBOX.latMax - BBOX.latMin)) * 100,
});

export default function FleetMapView({ buses, selectedId, onSelect, height = 180 }) {
  const el = useRef(null);
  const map = useRef(null);
  const markers = useRef({}); // id -> naver Marker
  const routeLine = useRef(null); // 선택된 버스 노선 폴리라인
  const [status, setStatus] = useState('loading');

  // 지도 생성 (1회)
  useEffect(() => {
    let cancelled = false;
    loadNaverMaps()
      .then((naver) => {
        if (cancelled || !el.current) return;
        const maps = naver.maps;
        map.current = new maps.Map(el.current, {
          center: new maps.LatLng(MAP_CENTER.lat, MAP_CENTER.lng),
          zoom: 14, scaleControl: false, mapDataControl: false,
        });
        setStatus('ready');
      })
      .catch(() => { if (!cancelled) setStatus('fallback'); });
    return () => { cancelled = true; };
  }, []);

  // 버스 마커 갱신 + 클릭 핸들러
  useEffect(() => {
    // 인증 실패로 지도가 무효화됐으면(naver.maps null) 크래시 대신 SVG 폴백으로 전환
    if (status === 'ready' && (!window.naver || !window.naver.maps)) {
      setStatus('fallback');
      return;
    }
    if (status !== 'ready') return;
    const maps = window.naver.maps;
    buses.forEach((b) => {
      const pos = new maps.LatLng(b.lat, b.lng);
      const content = fleetBusContent(b.label, b.onboard, b.id === selectedId, b.color);
      if (!markers.current[b.id]) {
        const m = new maps.Marker({ map: map.current, position: pos,
          icon: { content, anchor: new maps.Point(0, 0) }, zIndex: b.id === selectedId ? 200 : 100 });
        maps.Event.addListener(m, 'click', () => onSelect(b.id));
        markers.current[b.id] = m;
      } else {
        const m = markers.current[b.id];
        m.setPosition(pos);
        m.setIcon({ content, anchor: new maps.Point(0, 0) });
        m.setZIndex(b.id === selectedId ? 200 : 100);
      }
    });
  }, [buses, selectedId, status, onSelect]);

  // 선택된 버스의 노선(path) 폴리라인 표시
  useEffect(() => {
    if (status !== 'ready' || !window.naver || !window.naver.maps || !map.current) return;
    const maps = window.naver.maps;
    if (routeLine.current) { routeLine.current.setMap(null); routeLine.current = null; }
    const sel = buses.find((b) => b.id === selectedId);
    if (!sel || !sel.path) return;
    routeLine.current = new maps.Polyline({
      map: map.current,
      path: sel.path.map((p) => new maps.LatLng(p.lat, p.lng)),
      strokeColor: sel.color || '#2563eb', strokeWeight: 5, strokeOpacity: 0.85,
    });
  }, [buses, selectedId, status]);

  if (status === 'fallback') {
    const selBus = buses.find((b) => b.id === selectedId);
    const routePts = selBus && selBus.path ? selBus.path.map(toXY) : null;
    return (
      <div className="map" style={{ height }}>
        <svg viewBox="0 0 100 100" width="100%" height="100%" preserveAspectRatio="xMidYMid meet">
          <rect x="0" y="0" width="100" height="100" fill="#eef3f8" />
          {[20, 40, 60, 80].map((g) => (
            <g key={g}>
              <line x1={g} y1="0" x2={g} y2="100" stroke="#e0e7ef" strokeWidth="0.4" />
              <line x1="0" y1={g} x2="100" y2={g} stroke="#e0e7ef" strokeWidth="0.4" />
            </g>
          ))}
          {routePts && (
            <polyline
              points={routePts.map((p) => `${p.x},${p.y}`).join(' ')}
              fill="none" stroke={selBus.color || '#2563eb'} strokeWidth="1.6" strokeOpacity="0.85"
              strokeLinejoin="round"
            />
          )}
          {buses.map((b) => {
            const { x, y } = toXY(b);
            const sel = b.id === selectedId;
            return (
              <g key={b.id} onClick={() => onSelect(b.id)} style={{ cursor: 'pointer' }}>
                {sel && <circle cx={x} cy={y} r="5.2" fill={b.color} opacity="0.25" />}
                <circle cx={x} cy={y} r={sel ? 4 : 3.2} fill={b.color || '#2563eb'} stroke="#fff" strokeWidth="0.8" />
                <text x={x} y={y + 1.2} fontSize="3.4" textAnchor="middle" fill="#fff">🚌</text>
                <text x={x} y={y - 4.5} fontSize="3.2" textAnchor="middle" fill="#334155" fontWeight="700">{b.label}</text>
              </g>
            );
          })}
        </svg>
      </div>
    );
  }

  return (
    <div className="map" style={{ height }}>
      <div ref={el} style={{ width: '100%', height: '100%' }} />
      {status === 'loading' && <div className="map-skeleton" />}
    </div>
  );
}
