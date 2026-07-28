/// 간격·반경·터치 토큰.
///
/// 위젯에 `EdgeInsets.all(16)` 처럼 숫자를 직접 쓰지 않는다(컨벤션 §8) —
/// 값이 코드 곳곳에 흩어지면 여백을 한 번 조정하는 데 수십 군데를 고쳐야 한다.
/// 4의 배수 스케일을 쓴다(`docs/DESIGN_SYSTEM.md` §3).
class AppSpacing {
  const AppSpacing._();

  /// 아이콘·라벨 사이
  static const double xs = 4;

  /// 인접 버튼·칩 간격 — **오탭 방지 최소값**이다. 더 좁히지 않는다.
  static const double sm = 8;

  /// 행 내부 요소
  static const double smd = 12;

  /// 카드 패딩 · 화면 좌우 여백
  static const double md = 16;

  /// 섹션 사이
  static const double lg = 24;

  /// 화면 상단 여백
  static const double xl = 32;

  static const double xxl = 48;

  /// 칩·태그
  static const double radiusSm = 8;

  /// 버튼·입력·행
  static const double radiusMd = 12;

  /// 카드·시트
  static const double radiusLg = 20;
}

/// 터치 타깃 크기.
///
/// 이 앱은 **운전석에서, 장갑 낀 손으로, 흔들리는 차 안에서** 쓰인다
/// (`docs/DESIGN_BRIEF_DRIVER_MOBILE.md` §3). 그래서 터치 크기는
/// 미적 판단의 대상이 아니라 안전 요구사항이다.
class AppTouch {
  const AppTouch._();

  /// 탭 가능한 모든 요소의 최소 높이. 40dp 는 금지다.
  static const double min = 48;

  /// 화면당 하나뿐인 주요 동작(운행 시작·운행 종료 등).
  static const double primary = 56;
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
