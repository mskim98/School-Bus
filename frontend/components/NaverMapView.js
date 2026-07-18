'use client';

import { useEffect, useRef, useState } from 'react';
import { loadNaverMaps } from '@/lib/naverLoader';
import { PLACES, MAP_CENTER } from '@/lib/simulation';
import { useSim } from './SimulationProvider';
import MapView from './MapView';

// 실제 네이버 지도 위에 버스/학생 마커와 노선을 그린다.
// 키가 없거나 로드 실패 시 기존 SVG MapView 로 자동 폴백한다.
// 두 좌표 사이의 진행 방위각(0=북, 시계방향) — 마커 회전용
function bearing(a, b) {
  const dEast = (b.lng - a.lng) * Math.cos((a.lat * Math.PI) / 180);
  const dNorth = b.lat - a.lat;
  const deg = (Math.atan2(dEast, dNorth) * 180) / Math.PI;
  return (deg + 360) % 360;
}

// 진행방향 화살표를 두른 버스 마커 HTML (탑승 인원 있으면 초록 + 인원 배지)
function busContent(deg, count = 0) {
  const boarded = count > 0;
  const color = boarded ? '#16a34a' : '#2563eb';
  const badge = boarded
    ? `<div style="position:absolute;top:-4px;right:-4px;min-width:16px;height:16px;padding:0 3px;border-radius:999px;background:#16a34a;border:2px solid #fff;color:#fff;font-size:10px;font-weight:700;display:flex;align-items:center;justify-content:center;box-shadow:0 1px 3px rgba(0,0,0,.4)">${count}</div>`
    : '';
  return `<div style="position:relative;width:40px;height:40px;transform:translate(-50%,-50%)">
    <div style="position:absolute;inset:0;transform:rotate(${deg}deg)">
      <div style="position:absolute;top:-1px;left:50%;transform:translateX(-50%);width:0;height:0;border-left:6px solid transparent;border-right:6px solid transparent;border-bottom:10px solid ${color}"></div>
    </div>
    <div style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:28px;height:28px;border-radius:50%;background:${color};border:2px solid #fff;display:flex;align-items:center;justify-content:center;font-size:14px;box-shadow:0 2px 6px rgba(0,0,0,.4)">🚌${badge}</div>
  </div>`;
}

function studentContent(walking) {
  const emoji = walking ? '🚶' : '';
  return `<div style="transform:translate(-50%,-50%);width:24px;height:24px;border-radius:50%;background:#f97316;border:2px solid #fff;box-shadow:0 1px 4px rgba(0,0,0,.4);display:flex;align-items:center;justify-content:center;font-size:12px">${emoji}</div>`;
}

export default function NaverMapView({
  state,
  showStudent = true,
  showBus = true,
  height = 200,
  autoFollow = true,
}) {
  const { routes } = useSim();
  const el = useRef(null);
  const map = useRef(null);
  const busMarker = useRef(null);
  const studentMarker = useRef(null);
  const routeLines = useRef([]); // 노선/도보 폴리라인(경로 로드 시 교체)
  const lastBus = useRef(null); // 직전 버스 좌표(방위각 계산)
  const lastHeading = useRef(0);
  const [status, setStatus] = useState('loading'); // loading | ready | fallback

  // 최초 1회: 지도 + 정적 요소(장소 마커, 노선) 생성
  useEffect(() => {
    let cancelled = false;
    loadNaverMaps()
      .then((naver) => {
        if (cancelled || !el.current) return;
        const maps = naver.maps;
        map.current = new maps.Map(el.current, {
          center: new maps.LatLng(MAP_CENTER.lat, MAP_CENTER.lng),
          zoom: 15,
          scaleControl: false,
          mapDataControl: false,
        });

        // 경로 폴리라인은 아래 routes 전용 effect 에서 그린다(도로 좌표 로드 후)

        // 장소 마커
        const placePin = (label, color) =>
          `<div style="transform:translate(-50%,-50%);background:#fff;border:2px solid ${color};color:${color};font-size:11px;font-weight:700;padding:2px 6px;border-radius:8px;white-space:nowrap;box-shadow:0 1px 3px rgba(0,0,0,.2)">${label}</div>`;
        [
          [PLACES.home, '#64748b'],
          [PLACES.stopA, '#2563eb'],
          [PLACES.stopB, '#2563eb'],
          [PLACES.academy, '#0f766e'],
        ].forEach(([p, c]) => {
          new maps.Marker({
            map: map.current,
            position: new maps.LatLng(p.lat, p.lng),
            icon: { content: placePin(p.label, c), anchor: new maps.Point(0, 0) },
          });
        });

        // 정류장 근접 반경 표시(도착 예고 시각화)
        [PLACES.stopA, PLACES.stopB, PLACES.academy].forEach((p) => {
          new maps.Circle({
            map: map.current,
            center: new maps.LatLng(p.lat, p.lng),
            radius: 90,
            strokeColor: '#2563eb',
            strokeOpacity: 0.35,
            strokeWeight: 1,
            fillColor: '#2563eb',
            fillOpacity: 0.06,
          });
        });

        // 이동 마커(버스/학생)
        busMarker.current = new maps.Marker({
          map: map.current,
          position: new maps.LatLng(PLACES.busStart.lat, PLACES.busStart.lng),
          icon: { content: busContent(0), anchor: new maps.Point(0, 0) },
          zIndex: 100,
        });
        studentMarker.current = new maps.Marker({
          map: map.current,
          position: new maps.LatLng(PLACES.home.lat, PLACES.home.lng),
          icon: { content: studentContent(true), anchor: new maps.Point(0, 0) },
          zIndex: 101,
        });

        setStatus('ready');
      })
      .catch(() => {
        if (!cancelled) setStatus('fallback');
      });
    return () => {
      cancelled = true;
    };
  }, []);

  // 도로 경로가 준비되면 실제 도로 좌표로 폴리라인을 그린다
  useEffect(() => {
    if (status !== 'ready' || !window.naver || !window.naver.maps || !map.current) return;
    const maps = window.naver.maps;
    // 기존 라인 제거 후 재생성
    routeLines.current.forEach((l) => l.setMap(null));
    routeLines.current = [];

    const toPath = (arr) => arr.map((p) => new maps.LatLng(p.lat, p.lng));
    const add = (opts) => {
      routeLines.current.push(new maps.Polyline({ map: map.current, ...opts }));
    };

    if (routes && routes.walk && routes.busLegs) {
      // 버스 노선(도로) — 3구간 파란 실선
      routes.busLegs.forEach((leg) =>
        add({ path: toPath(leg), strokeColor: '#2563eb', strokeWeight: 5, strokeOpacity: 0.9 }));
      // 도보 경로(도로) — 초록 점선, 승차 전 학생 이동 경로 강조
      add({ path: toPath(routes.walk), strokeColor: '#16a34a', strokeWeight: 5, strokeStyle: 'shortdash', strokeOpacity: 0.95 });
    } else {
      // 폴백: 도로 좌표 없으면 지점 직선
      add({ path: toPath([PLACES.busStart, PLACES.stopA, PLACES.stopB, PLACES.academy]), strokeColor: '#2563eb', strokeWeight: 4 });
      add({ path: toPath([PLACES.home, PLACES.stopA]), strokeColor: '#16a34a', strokeWeight: 3, strokeStyle: 'shortdash' });
    }
  }, [status, routes]);

  // state 변경 시: 버스/학생 마커 위치·방향 갱신 + 활성 마커 자동 추적
  useEffect(() => {
    // 인증 실패로 지도가 무효화됐으면(naver.maps null) 크래시 대신 SVG 폴백으로 전환
    if (status === 'ready' && (!window.naver || !window.naver.maps)) {
      setStatus('fallback');
      return;
    }
    if (status !== 'ready') return;
    const maps = window.naver.maps;
    const { bus, student, boarded, onboardCount, phase } = state;

    if (busMarker.current) {
      const pos = new maps.LatLng(bus.lat, bus.lng);
      // 방위각: 이동량이 충분할 때만 갱신(정지 시 직전 방향 유지)
      if (lastBus.current) {
        const moved = Math.abs(bus.lat - lastBus.current.lat) + Math.abs(bus.lng - lastBus.current.lng);
        if (moved > 1e-6) lastHeading.current = bearing(lastBus.current, bus);
      }
      lastBus.current = { lat: bus.lat, lng: bus.lng };
      busMarker.current.setPosition(pos);
      busMarker.current.setIcon({ content: busContent(lastHeading.current, onboardCount), anchor: new maps.Point(0, 0) });
      busMarker.current.setVisible(showBus);
    }

    if (studentMarker.current) {
      const off = boarded ? 0.00035 : 0; // 탑승 중 버스와 겹침 방지
      studentMarker.current.setPosition(new maps.LatLng(student.lat + off, student.lng + off));
      studentMarker.current.setIcon({ content: studentContent(phase.key === 'walking'), anchor: new maps.Point(0, 0) });
      studentMarker.current.setVisible(showStudent);
    }

    // 자동 추적: 이동 주체(도보/대기=학생, 탑승/도착=버스)를 지도 중심에 고정
    if (autoFollow && map.current) {
      const followBus = !showStudent || phase.key === 'onboard' || phase.key === 'arrived';
      const target = followBus ? bus : student;
      if (followBus ? showBus : showStudent) {
        map.current.setCenter(new maps.LatLng(target.lat, target.lng));
      }
    }
  }, [state, status, showBus, showStudent, autoFollow]);

  if (status === 'fallback') {
    // 키 미설정/로드 실패 → SVG 지도로 폴백
    return <MapView state={state} showStudent={showStudent} showBus={showBus} height={height} />;
  }

  return (
    <div className="map" style={{ height }}>
      <div ref={el} style={{ width: '100%', height: '100%' }} />
      {status === 'loading' && <div className="map-skeleton" />}
    </div>
  );
}
