'use client';

import { use } from 'react';
import RoleShell from '@/components/RoleShell';

// 웹 콘솔 화면 — 학원 관리자/플랫폼 관리자. URL: /console/admin · /console/platform
export default function WebRolePage({ params }) {
  const { role } = use(params);
  return <RoleShell roleKey={role} medium="web" />;
}
