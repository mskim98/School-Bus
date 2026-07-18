'use client';

import Link from 'next/link';
import SimulationProvider, { useSim } from '@/components/SimulationProvider';
import PhoneFrame from '@/components/PhoneFrame';
import StudentApp from '@/components/StudentApp';
import ParentApp from '@/components/ParentApp';
import DriverApp from '@/components/DriverApp';
import AdminApp from '@/components/AdminApp';
import PlatformApp from '@/components/PlatformApp';
import WebFrame from '@/components/WebFrame';
import { tickToClock } from '@/lib/simulation';
import { useEffect, useState } from 'react';

function Controls() {
  const { t, playing, speed, setPlaying, setSpeed, reset, state, TOTAL_TICKS } = useSim();
  const pct = Math.round((t / TOTAL_TICKS) * 100);
  return (
    <>
      <div className="controls">
        <button onClick={() => setPlaying((p) => !p)}>{playing ? '⏸ 일시정지' : '▶ 재생'}</button>
        <button onClick={reset}>↺ 리셋</button>
        {[1, 2, 4].map((s) => (
          <button key={s} className={speed === s ? 'active' : ''} onClick={() => setSpeed(s)}>
            {s}x
          </button>
        ))}
        <span className="clock">🕗 {tickToClock(t)}</span>
        <span className="phase-chip">{state.phase.label}</span>
      </div>
      <div className="timeline">
        <div style={{ width: `${pct}%` }} />
      </div>
    </>
  );
}

// 사용자 계층 화면 정의 — 모바일 앱(학생/학부모/기사) vs 웹 콘솔(학원/플랫폼 관리자)
const MOBILE_ROLES = [
  { key: 'student', label: '🎒 학생', color: 'var(--student)', App: StudentApp },
  { key: 'parent', label: '👨‍👩‍👧 학부모', color: 'var(--parent)', App: ParentApp },
  { key: 'driver', label: '🚌 버스기사', color: 'var(--driver)', App: DriverApp },
];
const WEB_ROLES = [
  { key: 'admin', label: '🏫 학원 관리자 콘솔', url: 'admin.hanbit.school-bus.kr', App: AdminApp },
  { key: 'platform', label: '🛰️ 플랫폼 관리자 콘솔', url: 'console.school-bus.kr', App: PlatformApp },
];
const ROLES = [...MOBILE_ROLES, ...WEB_ROLES];

// 전체 화면 너비에 visible 프레임이 딱 맞도록 한 폰의 너비(px)를 계산
function fitWidth(count) {
  const gap = 28; // .phones gap
  const pad = 32; // 좌우 여유
  const avail = window.innerWidth - pad * 2 - gap * (count - 1);
  const w = avail / count;
  return Math.max(240, Math.min(560, Math.round(w)));
}

function Stage() {
  const [width, setWidth] = useState(360);
  const [autoFit, setAutoFit] = useState(true);
  // 표시할 화면 선택 (기본 전체 on)
  const [visible, setVisible] = useState(() => ROLES.map((r) => r.key));

  const shownMobile = MOBILE_ROLES.filter((r) => visible.includes(r.key));
  const shownWeb = WEB_ROLES.filter((r) => visible.includes(r.key));

  // 자동맞춤: 창 크기 + 표시된 모바일 화면 수에 맞춰 폰 너비를 재계산
  useEffect(() => {
    if (!autoFit) return;
    const apply = () => setWidth(fitWidth(shownMobile.length || 1));
    apply();
    window.addEventListener('resize', apply);
    return () => window.removeEventListener('resize', apply);
  }, [autoFit, shownMobile.length]);

  const toggle = (key) =>
    setVisible((v) => (v.includes(key) ? v.filter((k) => k !== key) : [...v, key]));

  return (
    <>
      <div className="size-bar">
        {ROLES.map((r) => (
          <label key={r.key} className={visible.includes(r.key) ? 'active' : ''}>
            <input
              type="checkbox"
              checked={visible.includes(r.key)}
              onChange={() => toggle(r.key)}
            />
            {r.label}
          </label>
        ))}
      </div>
      {shownMobile.length > 0 && (
        <div className="size-bar">
          <label className={autoFit ? 'active' : ''}>
            <input
              type="checkbox"
              checked={autoFit}
              onChange={(e) => setAutoFit(e.target.checked)}
            />
            모바일 화면 자동 맞춤
          </label>
          <input
            type="range"
            min="240"
            max="560"
            step="10"
            value={width}
            disabled={autoFit}
            onChange={(e) => setWidth(Number(e.target.value))}
          />
          <span className="size-val">{width}px</span>
        </div>
      )}

      {shownMobile.length > 0 && (
        <div className="phones" style={{ '--phone-w': `${width}px` }}>
          {shownMobile.map((r) => (
            <PhoneFrame key={r.key} role={r.label} color={r.color}>
              <r.App />
            </PhoneFrame>
          ))}
        </div>
      )}

      {shownWeb.length > 0 && (
        <div className="web-consoles">
          {shownWeb.map((r) => (
            <WebFrame key={r.key} title={r.label} url={r.url}>
              <r.App />
            </WebFrame>
          ))}
        </div>
      )}
    </>
  );
}

export default function DemoPage() {
  return (
    <SimulationProvider>
      <div className="page">
        <div className="page-header">
          <h1>통원버스 MVP — 5계층 통합 데모</h1>
          <p>
            하원 시나리오를 Mock 위치 스트림으로 재생합니다 · 학생·학부모·기사(모바일 앱)와
            학원·플랫폼 관리자(웹 콘솔)가 하나의 시뮬레이션으로 실시간 연동됩니다
          </p>
          <Link href="/login" className="demo-back-link">← 로그인 화면으로</Link>
        </div>
        <Controls />
        <Stage />
      </div>
    </SimulationProvider>
  );
}
