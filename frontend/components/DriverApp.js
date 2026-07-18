'use client';

import { useSim } from './SimulationProvider';
import NaverMapView from './NaverMapView';
import { phaseColor } from './PhaseStepper';
import { tickToClock, dailyLogSummary } from '@/lib/simulation';

export default function DriverApp() {
  const { state, checkIn } = useSim();
  const { phase, alighted, passengers, onboardCount, rideEvents } = state;
  const summary = alighted ? dailyLogSummary(passengers) : null;

  return (
    <div className="app">
      <div className="row">
        <div>
          <div className="muted">3호차 · 하원 노선 · 한빛학원</div>
          <div className="big-status">운행 중 · 탑승 {onboardCount}명</div>
        </div>
        <div className="status-badge" style={{ background: phaseColor(phase.key) }}>
          {phase.label}
        </div>
      </div>

      <div className="card">
        <h3>실시간 버스 위치</h3>
        <NaverMapView state={state} showStudent={false} showBus height={170} />
      </div>

      <div className="card">
        <h3>정류장별 탑승 명단</h3>
        {passengers.map((p) => (
          <RosterItem key={p.id} p={p} onCheck={checkIn} />
        ))}
        <div className="hint" style={{ marginTop: 6 }}>
          버스 도착 시 미확인 학생은 <b>승차 확인</b> 또는 <b>미탑승</b>을 눌러 처리하세요
        </div>
      </div>

      <div className="card">
        <h3>운행 로그</h3>
        {rideEvents.length === 0 ? (
          <div className="empty"><span className="empty-icon">🗒️</span>아직 승하차 기록이 없습니다</div>
        ) : (
          rideEvents.map((r, i) => (
            <div key={i} className="ride-item">
              <span>
                <span className={`tag ${r.type === '승차' ? 'on' : 'off'}`}>{r.type}</span>
                &nbsp;{r.name} · {r.place}
              </span>
              <span className="muted">{tickToClock(r.tick)}</span>
            </div>
          ))
        )}
        <div className="muted" style={{ marginTop: 8 }}>
          {alighted ? '전 구간 운행 종료 · 일일 로그 자동 생성됨' : '운행 중… 종료 시 로그가 자동 생성됩니다'}
        </div>
      </div>

      {summary && (
        <div className="card">
          <h3>일일 운행 로그 (자동 생성)</h3>
          <div className="ride-item"><span>운행 시간</span><span className="muted">{summary.startClock} ~ {summary.endClock}</span></div>
          <div className="ride-item"><span>총 배정</span><span className="muted">{summary.total}명</span></div>
          <div className="ride-item"><span>정상 승차</span><span className="muted">{summary.boarded}명</span></div>
          <div className="ride-item"><span>하차 완료</span><span className="muted">{summary.alighted}명</span></div>
          <div className="ride-item"><span>미탑승</span><span className="muted" style={{ color: summary.noshow ? '#dc2626' : undefined }}>{summary.noshow}명</span></div>
          <div className="ride-item"><span>결석(스킵)</span><span className="muted">{summary.absent}명</span></div>
        </div>
      )}
    </div>
  );
}

const STATUS_LABEL = {
  waiting: '대기', pending: '확인 대기', boarded: '탑승중',
  alighted: '하차완료', absent: '결석(스킵)', noshow: '미탑승',
};
const STATUS_COLOR = {
  waiting: '#64748b', pending: '#b45309', boarded: '#15803d',
  alighted: '#1d4ed8', absent: '#b91c1c', noshow: '#dc2626',
};

function RosterItem({ p, onCheck }) {
  const stopLabel = p.stop === 'stopA' ? '정류장 A' : '정류장 B';
  // 기사가 직접 확인해야 하는 상태(도착 대기 / 미탑승)면 액션 버튼 노출
  const needsAction = !p.live && (p.status === 'pending' || p.status === 'noshow');
  return (
    <div className="roster-item">
      <div>
        <div style={{ fontWeight: 700, fontSize: 14 }}>
          {p.name} {p.live && <span className="muted">· 실시간</span>}
        </div>
        <div className="muted">{stopLabel}</div>
      </div>
      {needsAction ? (
        <div style={{ display: 'flex', gap: 6 }}>
          <button className="mini-btn on" onClick={() => onCheck(p.id, 'boarded')}>승차 확인</button>
          <button className="mini-btn off" onClick={() => onCheck(p.id, 'absent')}>미탑승</button>
        </div>
      ) : (
        <span style={{ color: STATUS_COLOR[p.status], fontWeight: 700, fontSize: 13 }}>
          {STATUS_LABEL[p.status]}
        </span>
      )}
    </div>
  );
}
