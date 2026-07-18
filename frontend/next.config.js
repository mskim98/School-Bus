/** @type {import('next').NextConfig} */

// 프론트(:3000)에서 백엔드(:8080)로의 API 호출을 같은 출처(/api)로 프록시한다.
// 브라우저가 보기엔 동일 출처라 CORS 설정 없이 붙는다.
// 도커 컴포즈에서는 BACKEND_ORIGIN=http://backend:8080 으로 주입.
const BACKEND = process.env.BACKEND_ORIGIN || 'http://localhost:8080';

const nextConfig = {
  reactStrictMode: true,
  outputFileTracingRoot: __dirname,
  async rewrites() {
    return [{ source: '/api/:path*', destination: `${BACKEND}/api/:path*` }];
  },
};

module.exports = nextConfig;
