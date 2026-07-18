// 로그인/세션/로그아웃 — 백엔드 Spring Security(JWT)와 연동한다.
// access 토큰을 localStorage 에 보관하고, 토큰 payload 의 memberships("tenantId:ROLE")에서 역할을 읽는다.

const ACCESS_KEY = 'sb.access';
const REFRESH_KEY = 'sb.refresh';

// JWT payload 디코딩(서명 검증은 서버 몫, 여기선 역할 표시용으로 payload 만 읽는다)
function decodeJwt(token) {
  const payload = token.split('.')[1];
  const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
  const json = decodeURIComponent(
    atob(base64)
      .split('')
      .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
      .join('')
  );
  return JSON.parse(json);
}

// "tenantId:ROLE" → { tenantId, role }  (플랫폼 관리자는 ":PLATFORM_ADMIN" 처럼 tenant 없음)
function parseMembership(encoded) {
  if (!encoded) return { tenantId: null, role: null };
  const sep = encoded.indexOf(':');
  const tenant = encoded.slice(0, sep);
  return { tenantId: tenant || null, role: encoded.slice(sep + 1) };
}

export async function login(email, password) {
  const res = await fetch('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok || !json.success) {
    throw new Error(json.message || '로그인에 실패했습니다');
  }
  localStorage.setItem(ACCESS_KEY, json.data.accessToken);
  localStorage.setItem(REFRESH_KEY, json.data.refreshToken);
  return getSession();
}

// 현재 세션(로그인 정보). 없거나 만료면 null.
export function getSession() {
  if (typeof window === 'undefined') return null;
  const token = localStorage.getItem(ACCESS_KEY);
  if (!token) return null;
  try {
    const p = decodeJwt(token);
    if (p.exp && p.exp * 1000 < Date.now()) {
      logout();
      return null;
    }
    const memberships = p.memberships || [];
    const { tenantId, role } = parseMembership(memberships[0]);
    if (!role) return null;
    return { userId: p.sub, email: p.email, role, tenantId, memberships };
  } catch {
    return null;
  }
}

export function logout() {
  if (typeof window === 'undefined') return;
  localStorage.removeItem(ACCESS_KEY);
  localStorage.removeItem(REFRESH_KEY);
}

// 인증 헤더가 붙은 fetch — 역할 앱을 실제 백엔드 데이터로 연동할 때 사용한다.
export async function authFetch(path, options = {}) {
  const token = typeof window !== 'undefined' ? localStorage.getItem(ACCESS_KEY) : null;
  return fetch(path, {
    ...options,
    headers: {
      ...(options.headers || {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });
}
