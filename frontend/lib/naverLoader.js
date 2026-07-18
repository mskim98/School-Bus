// 네이버 지도 JS SDK(maps.js)를 한 번만 동적 로드하는 싱글턴 로더.
// 여러 지도 컴포넌트가 동시에 호출해도 script 태그는 하나만 삽입된다.
//
// 인증 파라미터가 키 종류에 따라 다르다:
//   - 2025 신규 Maps 키 → ncpKeyId
//   - 구 NCP Application Client ID → ncpClientId
// 어느 쪽인지 확실치 않으므로 ncpKeyId 로 먼저 시도하고, 인증 실패 시 ncpClientId 로 한 번 더 시도한다.
// 둘 다 실패(예: 콘솔에 localhost 도메인 미등록)하면 reject → 호출부가 SVG 지도로 폴백한다.
let promise = null;

export function loadNaverMaps() {
  if (typeof window === 'undefined') return Promise.reject(new Error('SSR'));
  if (window.naver && window.naver.maps) return Promise.resolve(window.naver);
  if (promise) return promise;

  const keyId = process.env.NEXT_PUBLIC_NAVER_MAP_ID;
  if (!keyId) return Promise.reject(new Error('NO_KEY'));

  const paramNames = ['ncpKeyId', 'ncpClientId'];

  promise = new Promise((resolve, reject) => {
    const attempt = (i) => {
      if (i >= paramNames.length) {
        // 모든 파라미터 시도 실패 — 도메인 미등록/키 오류 등. 폴백하도록 reject.
        window.__naverAuthFailed = true;
        reject(new Error('AUTH_FAILED'));
        return;
      }

      let settled = false;
      const script = document.createElement('script');
      script.src = `https://oapi.map.naver.com/openapi/v3/maps.js?${paramNames[i]}=${keyId}`;
      script.async = true;

      // 인증 실패(도메인 미등록/키 오류) 시 네이버 SDK 가 호출하는 전역 콜백.
      // onload 이후 비동기로 오는 경우가 있어, 다음 파라미터로 재시도한다.
      window.navermap_authFailure = () => {
        if (settled) return;
        settled = true;
        script.remove();
        try {
          delete window.naver;
        } catch {
          window.naver = undefined;
        }
        attempt(i + 1);
      };

      script.onload = () => {
        // 인증 실패 콜백이 조금 늦게 올 수 있어 한 틱 기다린 뒤 성공 확정
        setTimeout(() => {
          if (settled) return;
          if (window.naver && window.naver.maps) {
            settled = true;
            resolve(window.naver);
          } else {
            settled = true;
            attempt(i + 1);
          }
        }, 400);
      };
      script.onerror = () => {
        if (settled) return;
        settled = true;
        attempt(i + 1);
      };

      document.head.appendChild(script);
    };

    attempt(0);
  });

  return promise;
}
