'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { login, getSession } from '@/lib/auth';
import { roleHome } from '@/lib/roles';

// 데모 시드 계정(비밀번호 공통 "password") — 클릭 한 번으로 역할별 로그인 체험
const DEMO_ACCOUNTS = [
  { email: 'student@school.com', label: '🎒 학생', medium: '모바일 앱' },
  { email: 'parent@school.com', label: '👨‍👩‍👧 학부모', medium: '모바일 앱' },
  { email: 'driver@school.com', label: '🚌 버스기사', medium: '모바일 앱' },
  { email: 'admin@school.com', label: '🏫 학원 관리자', medium: '웹 콘솔' },
  { email: 'platform@school.com', label: '🛰️ 플랫폼 관리자', medium: '웹 콘솔' },
];

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  // 이미 로그인돼 있으면 자기 화면으로 바로 보낸다
  useEffect(() => {
    const s = getSession();
    if (s) router.replace(roleHome(s.role));
  }, [router]);

  const doLogin = async (e, presetEmail) => {
    if (e) e.preventDefault();
    setError('');
    setBusy(true);
    try {
      const session = await login(presetEmail || email, presetEmail ? 'password' : password);
      router.replace(roleHome(session.role));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-brand">🚌 통원버스</div>
        <div className="auth-sub">역할에 따라 다른 화면으로 로그인됩니다</div>

        <form className="auth-form" onSubmit={(e) => doLogin(e)}>
          <label>
            이메일
            <input type="email" value={email} placeholder="student@school.com"
              onChange={(e) => setEmail(e.target.value)} autoComplete="username" />
          </label>
          <label>
            비밀번호
            <input type="password" value={password} placeholder="password"
              onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" />
          </label>
          {error && <div className="auth-error">{error}</div>}
          <button type="submit" className="auth-submit" disabled={busy}>
            {busy ? '로그인 중…' : '로그인'}
          </button>
        </form>

        <div className="auth-divider">데모 계정으로 바로 체험 (비밀번호 password)</div>
        <div className="auth-demo-grid">
          {DEMO_ACCOUNTS.map((a) => (
            <button key={a.email} className="auth-demo" disabled={busy}
              onClick={() => doLogin(null, a.email)}>
              <span className="auth-demo-role">{a.label}</span>
              <span className="auth-demo-medium">{a.medium}</span>
            </button>
          ))}
        </div>

        <Link href="/demo" className="auth-demo-link">5계층 통합 시뮬레이션 데모 보기 →</Link>
      </div>
    </div>
  );
}
