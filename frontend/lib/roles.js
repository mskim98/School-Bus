// 역할(Role) → 화면 매핑. 백엔드 Role enum 5계층과 1:1 대응한다.
// medium: 'mobile'(학생/학부모/기사 → 폰 앱) vs 'web'(학원/플랫폼 관리자 → 웹 콘솔)

import StudentApp from '@/components/StudentApp';
import ParentApp from '@/components/ParentApp';
import DriverApp from '@/components/DriverApp';
import AdminApp from '@/components/AdminApp';
import PlatformApp from '@/components/PlatformApp';

export const ROLE_CONFIG = {
  STUDENT: { key: 'student', medium: 'mobile', label: '🎒 학생', color: 'var(--student)', App: StudentApp },
  PARENT: { key: 'parent', medium: 'mobile', label: '👨‍👩‍👧 학부모', color: 'var(--parent)', App: ParentApp },
  DRIVER: { key: 'driver', medium: 'mobile', label: '🚌 버스기사', color: 'var(--driver)', App: DriverApp },
  ACADEMY_ADMIN: { key: 'admin', medium: 'web', label: '🏫 학원 관리자 콘솔', url: 'admin.hanbit.school-bus.kr', App: AdminApp },
  PLATFORM_ADMIN: { key: 'platform', medium: 'web', label: '🛰️ 플랫폼 관리자 콘솔', url: 'console.school-bus.kr', App: PlatformApp },
};

// URL 세그먼트(key) → Role
export const KEY_TO_ROLE = Object.fromEntries(
  Object.entries(ROLE_CONFIG).map(([role, cfg]) => [cfg.key, role])
);

// 역할별 홈 경로 — 로그인 후 여기로 라우팅한다.
export function roleHome(role) {
  const cfg = ROLE_CONFIG[role];
  if (!cfg) return '/login';
  return cfg.medium === 'mobile' ? `/app/${cfg.key}` : `/console/${cfg.key}`;
}
