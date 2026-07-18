'use client';

import { useState } from 'react';
import { useSim } from './SimulationProvider';
import FleetMapView from './FleetMapView';
import { phaseColor } from './PhaseStepper';
import { computeFleet, tickToClock } from '@/lib/simulation';

// 학원 관리자: 자기 학원(한빛학원) 범위의 여러 버스를 지도에서 보고,
// 특정 버스를 선택해 실시간 추적·정보·명단을 확인한다.
export default function AdminApp() {
  const { state, t, scheduleReqs, decideScheduleReq, sos, clearSos } = useSim();
  const { phase, passengers, rideEvents } = state;

  const fleet = computeFleet(t, state);
  const [selectedId, setSelectedId] = useState('bus3'); // 기본: 실시간 3호차
  const selected = fleet.find((b) => b.id === selectedId) || fleet[0];

  const noShow = passengers.filter((p) => p.status === 'noshow').length;
  const absent = passengers.filter((p) => p.status === 'absent').length;
  const pendingReqs = scheduleReqs.filter((r) => r.status === 'pending');
  const overBuses = fleet.filter((b) => b.overCapacity); // 정원 초과 배정 버스(기능9)

  return (
    <div className="app">
      <div className="row">
        <div>
          <div className="muted">한빛학원 · 관리자 콘솔</div>
          <div className="big-status">운행 관제</div>
        </div>
        <div className="status-badge" style={{ background: phaseColor(phase.key) }}>
          {phase.label}
        </div>
      </div>

      {/* 학생 SOS 전파 (학부모와 동시 수신) */}
      {sos && (
        <div className="sos-banner">
          <div style={{ fontWeight: 800 }}>🚨 김민준 학생 긴급 SOS 접수</div>
          <div style={{ fontSize: 12, margin: '4px 0' }}>
            마지막 위치: {sos.lat.toFixed(5)}, {sos.lng.toFixed(5)} · {tickToClock(sos.at)}
          </div>
          <button className="mini-btn off" onClick={clearSos}>확인 (해제)</button>
        </div>
      )}

      {/* 정원 초과 배정 경고(기능9) */}
      {overBuses.length > 0 && (
        <div className="sos-banner" style={{ background: '#fffbeb', border: '1px solid #f59e0b', color: '#92400e' }}>
          <div style={{ fontWeight: 800 }}>⚠️ 정원 초과 배정 경고</div>
          <div style={{ fontSize: 12, marginTop: 4 }}>
            {overBuses.map((b) => `${b.label} (${b.assigned}/${b.capacity}명)`).join(', ')} — 배정 인원이 좌석 정원을 초과합니다
          </div>
        </div>
      )}

      <div className="card wide">
        <h3>오늘 운행 현황</h3>
        <div className="stat-grid">
          <div className="stat-box"><div className="stat-num">{fleet.filter((b) => b.running).length}</div><div className="stat-label">운행 중 버스</div></div>
          <div className="stat-box"><div className="stat-num">{fleet.reduce((a, b) => a + b.onboard, 0)}</div><div className="stat-label">전체 탑승 인원</div></div>
          <div className="stat-box"><div className="stat-num">{passengers.length}</div><div className="stat-label">A노선 배정 학생</div></div>
          <div className="stat-box"><div className="stat-num" style={{ color: noShow ? '#dc2626' : '#0f172a' }}>{noShow}</div><div className="stat-label">미탑승 (알림)</div></div>
        </div>
      </div>

      <div className="card wide">
        <h3>실시간 버스 관제 · 버스를 눌러 추적</h3>
        <FleetMapView buses={fleet} selectedId={selectedId} onSelect={setSelectedId} height={170} />
        <div className="bus-chips">
          {fleet.map((b) => (
            <button
              key={b.id}
              className={`bus-chip ${b.id === selectedId ? 'active' : ''}`}
              onClick={() => setSelectedId(b.id)}
            >
              🚌 {b.label} · {b.onboard}명{b.overCapacity && ' ⚠️'}
            </button>
          ))}
        </div>
      </div>

      {selected && (
        <div className="card">
          <h3>{selected.label} 상세 {selected.live && <span className="muted">· 실시간</span>}</h3>
          <div className="ride-item"><span>노선</span><span className="muted">{selected.route}</span></div>
          <div className="ride-item"><span>담당 기사</span><span className="muted">{selected.driver}</span></div>
          <div className="ride-item"><span>탑승 / 정원</span><span className="muted">{selected.onboard} / {selected.capacity}명</span></div>
          <div className="ride-item"><span>배정 / 정원</span>
            <span className="muted" style={{ color: selected.overCapacity ? '#b45309' : undefined, fontWeight: selected.overCapacity ? 700 : undefined }}>
              {selected.assigned} / {selected.capacity}명{selected.overCapacity && ' · 초과 ⚠️'}
            </span>
          </div>
          <div className="ride-item"><span>상태</span><span className="muted">{selected.phaseLabel}</span></div>
          {selected.live && (
            <div style={{ marginTop: 8 }}>
              <div className="muted" style={{ marginBottom: 4 }}>A노선 탑승 명단</div>
              {passengers.map((p) => (
                <div key={p.id} className="ride-item">
                  <span>{p.name}</span>
                  <span className="muted">{p.stop === 'stopA' ? '정류장 A' : '정류장 B'} · {STATUS_KO[p.status]}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      <div className="card">
        <h3>시간 변경 요청 승인 {pendingReqs.length > 0 && <span className="badge">{pendingReqs.length}</span>}</h3>
        {scheduleReqs.length === 0 && (
          <div className="empty"><span className="empty-icon">📝</span>대기 중인 요청이 없습니다</div>
        )}
        {scheduleReqs.map((r) => (
          <div key={r.id} className="req-item">
            <div>
              <div style={{ fontWeight: 700, fontSize: 13 }}>{r.from} · {r.type}</div>
              <div className="muted">{r.detail} · {tickToClock(r.tick)}</div>
            </div>
            {r.status === 'pending' ? (
              <div style={{ display: 'flex', gap: 6 }}>
                <button className="mini-btn on" onClick={() => decideScheduleReq(r.id, 'approved')}>승인</button>
                <button className="mini-btn off" onClick={() => decideScheduleReq(r.id, 'rejected')}>거절</button>
              </div>
            ) : (
              <span style={{ fontWeight: 700, fontSize: 13, color: r.status === 'approved' ? '#15803d' : '#b91c1c' }}>
                {r.status === 'approved' ? '승인됨' : '거절됨'}
              </span>
            )}
          </div>
        ))}
      </div>

      <div className="card">
        <h3>예외 관리</h3>
        {noShow === 0 && absent === 0 && (
          <div className="empty"><span className="empty-icon">✅</span>처리할 예외가 없습니다</div>
        )}
        {passengers.filter((p) => p.status === 'noshow').map((p) => (
          <div key={p.id} className="noti-item noshow">
            {p.name} — {p.stop === 'stopA' ? '정류장 A' : '정류장 B'} 미탑승 · 확인 필요
          </div>
        ))}
        {passengers.filter((p) => p.status === 'absent').map((p) => (
          <div key={p.id} className="ride-item">
            <span>{p.name}</span>
            <span className="muted">결석 신고 · 노선 스킵 처리됨</span>
          </div>
        ))}
      </div>

      <div className="card">
        <h3>승하차 로그 (A노선 전체)</h3>
        {rideEvents.length === 0 && (
          <div className="empty"><span className="empty-icon">🗒️</span>아직 기록이 없습니다</div>
        )}
        {rideEvents.map((r, i) => (
          <div key={i} className="ride-item">
            <span>
              <span className={`tag ${r.type === '승차' ? 'on' : 'off'}`}>{r.type}</span>
              &nbsp;{r.name} · {r.place}
            </span>
            <span className="muted">{tickToClock(r.tick)}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

const STATUS_KO = {
  waiting: '대기', pending: '확인 대기', boarded: '탑승중',
  alighted: '하차완료', absent: '결석', noshow: '미탑승',
};
