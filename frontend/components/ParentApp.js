'use client';

import { useEffect, useRef, useState } from 'react';
import { useSim } from './SimulationProvider';
import NaverMapView from './NaverMapView';
import PhaseStepper, { phaseColor } from './PhaseStepper';
import { tickToClock, RIDE_HISTORY } from '@/lib/simulation';

export default function ParentApp() {
  const { state, sos, clearSos, scheduleReqs, submitScheduleReq,
    reportAbsence, cancelAbsence } = useSim();
  const { phase, eta, myAbsent } = state;
  const notifications = state.notifications.filter((n) => !n.to || n.to.includes('parent'));
  const rideEvents = state.rideEvents.filter((r) => r.live);
  const reported = myAbsent; // 결석 신고는 시뮬 상태(명단 스킵)와 실제 연동
  const [reqOpen, setReqOpen] = useState(false);

  const myReqs = scheduleReqs.filter((r) => r.from.includes('김민준'));

  // 새 알림 도착 시 토스트 (알림 개수 증가 감지)
  const [toast, setToast] = useState(null);
  const prevCount = useRef(0);
  useEffect(() => {
    if (notifications.length > prevCount.current) {
      const latest = notifications[notifications.length - 1];
      setToast(latest.text);
      const timer = setTimeout(() => setToast(null), 3200);
      prevCount.current = notifications.length;
      return () => clearTimeout(timer);
    }
    prevCount.current = notifications.length;
    return undefined;
  }, [notifications.length]);

  return (
    <div className="app">
      {toast && (
        <div className="toast"><span className="toast-dot" />{toast}</div>
      )}
      <div className="row">
        <div>
          <div className="muted">자녀 실시간 추적</div>
          <div className="big-status">김민준 (통합 추적)</div>
        </div>
        <div className="status-badge" style={{ background: phaseColor(phase.key) }}>
          {phase.label}
        </div>
      </div>

      {/* SOS 전파 배너 */}
      {sos && (
        <div className="sos-banner">
          <div style={{ fontWeight: 800 }}>🚨 자녀가 긴급 SOS를 보냈습니다</div>
          <div style={{ fontSize: 12, margin: '4px 0' }}>
            마지막 위치: {sos.lat.toFixed(5)}, {sos.lng.toFixed(5)} · {tickToClock(sos.at)}
          </div>
          <button className="mini-btn off" onClick={clearSos}>확인 (해제)</button>
        </div>
      )}

      {eta && (
        <div className="eta-card">
          <div className="eta-big">{eta.min}분</div>
          <div className="eta-sub">{eta.kind === 'toStop' ? `버스 ${eta.target} 도착까지` : `${eta.target} 도착까지`}</div>
        </div>
      )}

      <PhaseStepper phaseKey={phase.key} />

      <div className="card">
        <h3>도보 → 대기 → 버스 통합 지도</h3>
        <NaverMapView state={state} showStudent showBus height={200} />
        <div className="muted" style={{ marginTop: 8 }}>
          화면 전환 없이 도보·정류장·버스 이동을 하나의 지도에서 추적
        </div>
      </div>

      <div className="card">
        <h3>
          알림함
          {notifications.length > 0 && <span className="badge">{notifications.length}</span>}
        </h3>
        {notifications.length === 0 && (
          <div className="empty"><span className="empty-icon">🔔</span>새 알림이 없어요</div>
        )}
        {[...notifications].reverse().map((n) => (
          n.type === 'safe' ? (
            <div key={n.id} className="safe-card">
              <div className="safe-photo">📷</div>
              <div>
                <div style={{ fontWeight: 700, fontSize: 13 }}>{n.text}</div>
                <div className="noti-time">안심 하차 확인 · {tickToClock(n.tick)}</div>
              </div>
            </div>
          ) : (
            <div key={n.id} className={`noti-item ${n.type === 'sos' ? 'sos' : n.type === 'noshow' ? 'noshow' : ''}`}>
              {n.text}
              <div className="noti-time">{tickToClock(n.tick)}</div>
            </div>
          )
        ))}
      </div>

      <div className="card">
        <h3>오늘 승하차 기록</h3>
        {myAbsent ? (
          <div className="empty"><span className="empty-icon">🏠</span>오늘 결석 신고됨 · 통원 없음</div>
        ) : rideEvents.length === 0 ? (
          <div className="empty"><span className="empty-icon">🗓️</span>오늘 기록이 아직 없어요</div>
        ) : (
          rideEvents.map((r, i) => (
            <div key={i} className="ride-item">
              <span>
                <span className={`tag ${r.type === '승차' ? 'on' : 'off'}`}>{r.type}</span>
                &nbsp;{r.place}
              </span>
              <span className="muted">{tickToClock(r.tick)}</span>
            </div>
          ))
        )}
      </div>

      {/* 승하차 기록 캘린더(기능2) — 지난 통원일 이력 */}
      <div className="card">
        <h3>지난 승하차 기록 (캘린더)</h3>
        {RIDE_HISTORY.map((d) => (
          <div key={d.date} className="ride-item">
            <span>
              <span className={`tag ${d.status === 'absent' ? 'off' : 'on'}`}>{d.date}</span>
              &nbsp;{d.board}{d.status !== 'absent' && ` → ${d.alight}`}
            </span>
            <span className="muted" style={{ color: d.status === 'late' ? '#b45309' : d.status === 'absent' ? '#b91c1c' : undefined }}>
              {d.status === 'late' ? '지각' : d.status === 'absent' ? '결석' : '정상'}
            </span>
          </div>
        ))}
      </div>

      {/* 시간 변경 요청 워크플로 */}
      <div className="card">
        <h3>시간 변경 요청</h3>
        {myReqs.length === 0 && !reqOpen && (
          <div className="muted" style={{ marginBottom: 8 }}>하원 픽업 시간 변경을 학원에 요청할 수 있어요</div>
        )}
        {myReqs.map((r) => (
          <div key={r.id} className="req-item">
            <div>
              <div style={{ fontWeight: 700, fontSize: 13 }}>{r.type}</div>
              <div className="muted">{r.detail}</div>
            </div>
            <span style={{ fontWeight: 700, fontSize: 13,
              color: r.status === 'approved' ? '#15803d' : r.status === 'rejected' ? '#b91c1c' : '#b45309' }}>
              {r.status === 'approved' ? '승인됨' : r.status === 'rejected' ? '거절됨' : '검토 중'}
            </span>
          </div>
        ))}
        {reqOpen ? (
          <div className="req-form">
            {['오늘 하원 30분 늦춤', '오늘 하원 30분 당김', '내일 결석(픽업 스킵)'].map((opt) => (
              <button key={opt} className="req-opt"
                onClick={() => { submitScheduleReq({ from: '김민준 학부모', type: '하원 시간 변경', detail: opt }); setReqOpen(false); }}>
                {opt}
              </button>
            ))}
            <button className="btn btn-outline" onClick={() => setReqOpen(false)}>취소</button>
          </div>
        ) : (
          <button className="btn btn-outline" onClick={() => setReqOpen(true)}>+ 시간 변경 요청하기</button>
        )}
      </div>

      <button
        className={`btn ${reported ? 'btn-outline' : 'btn-primary'}`}
        onClick={() => (reported ? cancelAbsence('kim') : reportAbsence('kim'))}
      >
        {reported ? '✓ 오늘 결석 신고됨 (취소)' : '결석 / 휴원 신고'}
      </button>
      <div className="hint">
        {reported
          ? '기사 명단·관리자 예외 관리에 스킵 처리가 실시간 반영됩니다'
          : '결석 신고 시 기사 명단에서 자동 스킵 처리'}
      </div>
    </div>
  );
}
