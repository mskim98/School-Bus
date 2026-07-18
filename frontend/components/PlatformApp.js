'use client';

import { useState } from 'react';
import { useSim } from './SimulationProvider';
import FleetMapView from './FleetMapView';
import { computeAllBuses, TENANTS } from '@/lib/simulation';

// 플랫폼 관리자: 여러 학원(멀티 테넌트)의 모든 버스를 지도에서 관제.
// 학원별로 묶어 보거나(테넌트 필터) 전체를 한 번에 볼 수 있다.
// 한빛학원 3호차만 실시간 시뮬 연동, 나머지는 Mock 운행.
export default function PlatformApp() {
  const { state, t } = useSim();
  const allBuses = computeAllBuses(t, state);
  const [tenantFilter, setTenantFilter] = useState('all'); // 'all' | tenantId
  const [selectedId, setSelectedId] = useState(null);

  // 필터에 따라 지도에 표시할 버스
  const buses = tenantFilter === 'all' ? allBuses : allBuses.filter((b) => b.tenant === tenantFilter);
  const selected = allBuses.find((b) => b.id === selectedId);

  // 학원별 집계 (필터 시 해당 학원만)
  const byTenant = TENANTS
    .filter((ten) => tenantFilter === 'all' || ten.id === tenantFilter)
    .map((ten) => {
      const bs = allBuses.filter((b) => b.tenant === ten.id);
      return { ...ten, buses: bs, running: bs.filter((b) => b.running).length,
        total: bs.length, onboard: bs.reduce((a, b) => a + b.onboard, 0) };
    });

  const totRunning = allBuses.filter((b) => b.running).length;
  const totOnboard = allBuses.reduce((a, b) => a + b.onboard, 0);

  const selectTenant = (id) => {
    setTenantFilter(id);
    setSelectedId(null); // 학원 전환 시 선택 초기화
  };

  return (
    <div className="app">
      <div className="row">
        <div>
          <div className="muted">플랫폼 관리자 · 전체 테넌트</div>
          <div className="big-status">멀티 학원 통합 관제</div>
        </div>
        <div className="status-badge" style={{ background: '#7c3aed' }}>실시간</div>
      </div>

      <div className="card wide">
        <h3>플랫폼 집계</h3>
        <div className="stat-grid">
          <div className="stat-box"><div className="stat-num">{TENANTS.length}</div><div className="stat-label">활성 학원 (tenant)</div></div>
          <div className="stat-box"><div className="stat-num">{totRunning}/{allBuses.length}</div><div className="stat-label">운행 중 / 전체 버스</div></div>
          <div className="stat-box"><div className="stat-num">{totOnboard}</div><div className="stat-label">현재 탑승 인원</div></div>
          <div className="stat-box"><div className="stat-num">{TENANTS.length}</div><div className="stat-label">운행 노선 그룹</div></div>
        </div>
      </div>

      {/* 학원(테넌트) 필터 — 학원별로 묶어 보기 */}
      <div className="card wide">
        <h3>학원별 관제 · 학원을 선택해 묶어 보기</h3>
        <div className="tenant-tabs">
          <button className={`tenant-tab ${tenantFilter === 'all' ? 'active' : ''}`} onClick={() => selectTenant('all')}>
            전체 학원
          </button>
          {TENANTS.map((ten) => (
            <button key={ten.id}
              className={`tenant-tab ${tenantFilter === ten.id ? 'active' : ''}`}
              onClick={() => selectTenant(ten.id)}>
              {ten.name}
            </button>
          ))}
        </div>
        <FleetMapView buses={buses} selectedId={selectedId} onSelect={setSelectedId} height={200} />
        {selected ? (
          <div className="sel-detail" style={{ borderLeft: `4px solid ${selected.color}` }}>
            <div style={{ fontWeight: 700, fontSize: 14 }}>
              {selected.tenantName} · {selected.label} {selected.live && <span className="muted">· 실시간</span>}
            </div>
            <div className="muted">{selected.route} · {selected.driver} · 탑승 {selected.onboard}/{selected.capacity} · {selected.phaseLabel}</div>
          </div>
        ) : (
          <div className="muted" style={{ marginTop: 8 }}>지도/칩에서 버스를 선택하면 소속 학원·노선·기사·탑승 정보와 노선을 봅니다</div>
        )}
      </div>

      {/* 학원별 그룹 카드 */}
      {byTenant.map((ten) => (
        <div key={ten.id} className="card">
          <h3>{ten.name}</h3>
          <div className="muted" style={{ marginBottom: 8 }}>
            버스 {ten.running}/{ten.total} 운행 · 현재 탑승 {ten.onboard}명
          </div>
          <div className="bus-chips">
            {ten.buses.map((b) => (
              <button
                key={b.id}
                className={`bus-chip ${b.id === selectedId ? 'active' : ''} ${b.running ? '' : 'idle'}`}
                style={b.id === selectedId ? { borderColor: b.color, background: `${b.color}18`, color: b.color } : { borderLeft: `4px solid ${b.color}` }}
                onClick={() => setSelectedId(b.id)}
              >
                🚌 {b.label} · {b.running ? `${b.onboard}명` : '대기'}
              </button>
            ))}
          </div>
        </div>
      ))}

      <div className="card">
        <h3>플랫폼 운영 지표 (Mock)</h3>
        <div className="ride-item"><span>금일 총 승하차 이벤트</span><span className="muted">1,284건</span></div>
        <div className="ride-item"><span>알림 발송 성공률</span><span className="muted">99.2%</span></div>
        <div className="ride-item"><span>평균 위치 수신 지연</span><span className="muted">1.4초</span></div>
      </div>
    </div>
  );
}
