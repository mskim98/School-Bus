import { redirect } from 'next/navigation';

// 진입점은 로그인. 로그인 후 역할(Role)에 따라 /app/* (모바일) 또는 /console/* (웹)로 분기한다.
export default function Home() {
  redirect('/login');
}
