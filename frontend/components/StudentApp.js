'use client';

import { useSim } from './SimulationProvider';
import NaverMapView from './NaverMapView';
import PhaseStepper, { phaseColor } from './PhaseStepper';
import { PLACES, tickToClock, walkRemainingMin } from '@/lib/simulation';

export default function StudentApp() {
  const { state, t, sos, triggerSos } = useSim();
  const { phase, eta } = state;
  const rideEvents = state.rideEvents.filter((r) => r.live); // 본인 기록만

  const walkTarget = PLACES.stopA.label;
  // 대기 중 버스가 곧(3분 이내) 도착하면 승차 준비 CTA
  const boardingSoon = phase.key === 'waiting' && eta && eta.kind === 'toStop' && eta.min <= 3;

  return (
    <div className="app">
      <div className="row">
        <div>
          <div className="muted">안녕하세요</div>
          <div className="big-status">김민준 학생</div>
        </div>
        <div className="status-badge" style={{ background: phaseColor(phase.key) }}>
          {phase.label}
        </div>
      </div>

      {eta && (
        <div className={`eta-card ${boardingSoon ? 'urgent' : ''}`}>
          <div className="eta-big">{eta.min}분</div>
          <div className="eta-sub">
            {boardingSoon
              ? '🚸 곧 도착! 정류장에서 대기하세요'
              : `${eta.target} 도착 예정`}
          </div>
        </div>
      )}

      <PhaseStepper phaseKey={phase.key} />

      <div className="card">
        <h3>내 위치 · 도보 경로</h3>
        <NaverMapView state={state} showStudent showBus={phase.key !== 'walking'} height={190} />
        <div className="muted" style={{ marginTop: 8 }}>
          {phase.key === 'walking' && `${walkTarget}까지 도보 이동 중 · 약 ${walkRemainingMin(t)}분 남음`}
          {phase.key === 'waiting' && `${walkTarget} 도착 · 버스 대기 중`}
          {phase.key === 'onboard' && '버스 탑승 중 · 학원으로 이동'}
          {phase.key === 'arrived' && '학원 도착 완료'}
        </div>
      </div>

      <div className="card">
        <h3>오늘 승하차 기록</h3>
        {rideEvents.length === 0 && (
          <div className="empty"><span className="empty-icon">🗒️</span>아직 승하차 기록이 없어요</div>
        )}
        {rideEvents.map((r, i) => (
          <div key={i} className="ride-item">
            <span>
              <span className={`tag ${r.type === '승차' ? 'on' : 'off'}`}>{r.type}</span>
              &nbsp;{r.place}
            </span>
            <span className="muted">{tickToClock(r.tick)}</span>
          </div>
        ))}
      </div>

      <button
        className="btn btn-sos"
        onClick={triggerSos}
      >
        {sos ? '🚨 SOS 발송됨 — 보호자·관리자에 전파 중' : '🚨 긴급 SOS 호출'}
      </button>
      <div className="hint">SOS 시 마지막 위치와 함께 학부모·관리자에 즉시 전파</div>
    </div>
  );
}
