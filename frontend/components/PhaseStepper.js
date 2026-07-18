'use client';

// 통원 진행 4단계 시각화 (도보 → 대기 → 탑승 → 하차)
export const PHASE_STEPS = [
  { key: 'walking', label: '도보', icon: '🚶', color: '#f97316' },
  { key: 'waiting', label: '대기', icon: '🚏', color: '#f59e0b' },
  { key: 'onboard', label: '탑승', icon: '🚌', color: '#2563eb' },
  { key: 'arrived', label: '하차', icon: '🏫', color: '#16a34a' },
];

export function phaseColor(key) {
  return (PHASE_STEPS.find((s) => s.key === key) || PHASE_STEPS[0]).color;
}

export default function PhaseStepper({ phaseKey }) {
  const current = Math.max(0, PHASE_STEPS.findIndex((s) => s.key === phaseKey));
  return (
    <div className="stepper">
      {PHASE_STEPS.map((s, i) => {
        const stateCls = i < current ? 'done' : i === current ? 'active' : 'todo';
        return (
          <div key={s.key} className="step-wrap">
            {i > 0 && <div className={`step-line ${i <= current ? 'fill' : ''}`} />}
            <div className={`step ${stateCls}`} title={s.label}>
              <span className="step-icon">{i < current ? '✓' : s.icon}</span>
              <span className="step-label">{s.label}</span>
            </div>
          </div>
        );
      })}
    </div>
  );
}
