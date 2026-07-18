'use client';

import { use } from 'react';
import RoleShell from '@/components/RoleShell';

// 모바일 앱 화면 — 학생/학부모/기사. URL: /app/student · /app/parent · /app/driver
export default function MobileRolePage({ params }) {
  const { role } = use(params);
  return <RoleShell roleKey={role} medium="mobile" />;
}
