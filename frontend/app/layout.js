import './globals.css';

export const metadata = {
  title: '통원버스 MVP',
  description: '학생·학부모·기사(모바일)와 학원·플랫폼 관리자(웹)를 역할별로 로그인 분기하는 통원버스 데모',
};

export default function RootLayout({ children }) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
