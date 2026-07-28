/// 간격·반경 토큰.
///
/// 위젯에 `EdgeInsets.all(16)` 처럼 숫자를 직접 쓰지 않는다(컨벤션 §8) —
/// 값이 코드 곳곳에 흩어지면 여백을 한 번 조정하는 데 수십 군데를 고쳐야 한다.
/// 4의 배수 스케일을 쓴다.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// 모서리 반경
  static const double radiusSm = 6;
  static const double radiusMd = 12;
  static const double radiusLg = 20;
}

/// 반응형 분기 기준점.
///
/// 이 앱은 한 코드베이스로 **기사(모바일 레이아웃)** 와 **관리자(데스크톱 레이아웃)** 를
/// 모두 그린다(계획서 §1.2). 폭 분기를 화면마다 다른 숫자로 하면 레이아웃이 어긋나므로
/// 기준을 여기 한 곳에 둔다.
class AppBreakpoints {
  const AppBreakpoints._();

  /// 이 폭 미만이면 모바일 레이아웃(기사 앱 형태)
  static const double compact = 720;

  /// 이 폭 이상이면 관제용 넓은 레이아웃(사이드바 + 지도)
  static const double expanded = 1200;
}
