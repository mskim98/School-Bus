'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { getSession, logout } from '@/lib/auth';
import { ROLE_CONFIG, KEY_TO_ROLE, roleHome } from '@/lib/roles';
import SimulationProvider from '@/components/SimulationProvider';
import PhoneFrame from '@/components/PhoneFrame';
import WebFrame from '@/components/WebFrame';

// 로그인한 사용자의 역할 화면을 렌더한다.
// - 세션이 없으면 /login 으로, 역할이 URL 과 다르면 자기 홈으로 리다이렉트(역할 가드)
// - mobile 역할은 PhoneFrame, web 역할은 WebFrame 으로 감싼다
export default function RoleShell({ roleKey, medium }) {
  const router = useRouter();
  const [session, setSession] = useState(undefined); // undefined=확인중, null=없음

  useEffect(() => {
    const s = getSession();
    if (!s) {
      router.replace('/login');
      return;
    }
    const expectedRole = KEY_TO_ROLE[roleKey];
    if (s.role !== expectedRole) {
      router.replace(roleHome(s.role)); // 잘못된 역할 주소 → 자기 화면으로
      return;
    }
    setSession(s);
  }, [roleKey, router]);

  if (session === undefined) return <div className="auth-loading">불러오는 중…</div>;
  if (session === null) return null;

  const cfg = ROLE_CONFIG[session.role];
  const App = cfg.App;
  const onLogout = () => {
    logout();
    router.replace('/login');
  };

  const bar = (
    <div className="session-bar">
      <span className="session-role">{cfg.label}</span>
      <span className="session-user">{session.email}</span>
      <button className="session-logout" onClick={onLogout}>로그아웃</button>
    </div>
  );

  return (
    <SimulationProvider>
      {medium === 'mobile' ? (
        <div className="screen-mobile">
          {bar}
          <div className="phones single" style={{ '--phone-w': '390px' }}>
            <PhoneFrame role={cfg.label} color={cfg.color}>
              <App />
            </PhoneFrame>
          </div>
        </div>
      ) : (
        <div className="screen-web">
          {bar}
          <div className="web-consoles">
            <WebFrame title={cfg.label} url={cfg.url}>
              <App />
            </WebFrame>
          </div>
        </div>
      )}
    </SimulationProvider>
  );
}
