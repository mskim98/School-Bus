'use client';

// 관리자 콘솔용 데스크톱(웹) 프레임 — 브라우저 창 형태로 넓게 표시
export default function WebFrame({ title, url, children }) {
  return (
    <div className="web-frame">
      <div className="web-bar">
        <span className="web-dots"><span /><span /><span /></span>
        <span className="web-url">{url}</span>
        <span className="web-title">{title}</span>
      </div>
      <div className="web-body">{children}</div>
    </div>
  );
}
