'use client';

import { createContext, useContext, useEffect, useRef, useState } from 'react';
import { computeState, TOTAL_TICKS } from '@/lib/simulation';
import { fetchRoutes } from '@/lib/routing';

const SimContext = createContext(null);

export function useSim() {
  const ctx = useContext(SimContext);
  if (!ctx) throw new Error('useSim must be used within SimulationProvider');
  return ctx;
}

export default function SimulationProvider({ children }) {
  const [t, setT] = useState(0);
  const [playing, setPlaying] = useState(true);
  const [speed, setSpeed] = useState(1); // 1x, 2x, 4x
  const [routes, setRoutes] = useState(null); // 도로 경로(OSRM), 로드 전엔 직선 폴백
  const [checkins, setCheckins] = useState({}); // 기사 수동확인: { [studentId]: 'boarded'|'absent' }
  const [sos, setSos] = useState(null); // { at, lat, lng } — 학생 SOS, 학부모·관리자 전파
  const [scheduleReqs, setScheduleReqs] = useState([]); // 시간변경 요청 워크플로
  const [absences, setAbsences] = useState([]); // 학부모 결석 신고 → 기사·관리자 명단 자동 스킵
  const timer = useRef(null);

  // 최초 1회: 실제 도로 경로를 받아온다 (실패 시 null 유지 → 직선 폴백)
  useEffect(() => {
    let cancelled = false;
    fetchRoutes()
      .then((r) => { if (!cancelled) setRoutes(r); })
      .catch(() => {});
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    if (!playing) return undefined;
    // 분수 스텝(0.1틱/80ms)으로 진행 → 마커가 끊김 없이 부드럽게 이동
    // 기본 속도(1x) = 1.25틱/초로 이전과 동일, speed 배율 적용
    const STEP = 0.1 * speed;
    timer.current = setInterval(() => {
      setT((prev) => {
        if (prev >= TOTAL_TICKS) {
          setPlaying(false);
          return TOTAL_TICKS;
        }
        return Math.min(prev + STEP, TOTAL_TICKS);
      });
    }, 80);
    return () => clearInterval(timer.current);
  }, [playing, speed]);

  const reset = () => {
    setT(0);
    setPlaying(true);
    setCheckins({}); // 기사 수동확인도 초기화
    setSos(null);
    setScheduleReqs([]);
    setAbsences([]);
  };

  // 학부모 결석/휴원 신고 → 명단 자동 스킵 (기사·관리자 앱에 실시간 반영)
  const reportAbsence = (id) => setAbsences((a) => (a.includes(id) ? a : [...a, id]));
  const cancelAbsence = (id) => setAbsences((a) => a.filter((x) => x !== id));

  // 기사 수동 승하차 확인 (미탑승 알림 방지)
  const checkIn = (id, value) => setCheckins((c) => ({ ...c, [id]: value }));

  // 학생 SOS 발신 → 학부모·관리자에 마지막 위치와 함께 전파
  const state = computeState(t, routes, checkins, absences);
  const triggerSos = () => setSos({ at: t, lat: state.student.lat, lng: state.student.lng });
  const clearSos = () => setSos(null);

  // 시간변경 요청: 학부모 제출 → 관리자 승인/거절
  const submitScheduleReq = (req) =>
    setScheduleReqs((rs) => [...rs, { id: Date.now(), status: 'pending', tick: t, ...req }]);
  const decideScheduleReq = (id, status) =>
    setScheduleReqs((rs) => rs.map((r) => (r.id === id ? { ...r, status } : r)));

  const value = { state, t, playing, speed, setPlaying, setSpeed, reset, TOTAL_TICKS,
    routes, checkins, checkIn, sos, triggerSos, clearSos,
    scheduleReqs, submitScheduleReq, decideScheduleReq,
    absences, reportAbsence, cancelAbsence };
  return <SimContext.Provider value={value}>{children}</SimContext.Provider>;
}
