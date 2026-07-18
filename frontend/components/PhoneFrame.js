'use client';

export default function PhoneFrame({ role, color, children }) {
  return (
    <div className="phone">
      <div className="phone-notch" />
      <div className="phone-topbar" style={{ background: color }}>
        <span>{role}</span>
        <span className="phone-time">08:00</span>
      </div>
      <div className="phone-screen">{children}</div>
      <div className="phone-home" />
    </div>
  );
}
