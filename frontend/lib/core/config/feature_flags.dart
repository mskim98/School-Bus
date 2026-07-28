/// 빌드 시점에 켜고 끄는 기능 플래그.
///
/// 런타임 설정이 아니라 **빌드 플래그**로 둔 이유 — 꺼진 기능은 트리 셰이킹으로
/// 번들에서 아예 사라진다. 운영 빌드에 테스트용 코드가 딸려가지 않는다.
class FeatureFlags {
  const FeatureFlags._();

  /// 로그인 화면의 빠른 로그인(시드 계정 원터치) 노출 여부. **기본값 false.**
  ///
  /// 인증을 우회하는 게 아니라 시드 계정으로 **정상 로그인**을 대신 눌러줄 뿐이다
  /// (토큰 없이는 모든 API 가 401 이라 우회는 애초에 쓸모가 없다).
  /// 그래도 계정 목록이 화면에 노출되므로 운영 빌드에서는 반드시 꺼둔다.
  ///
  /// 켜는 법:
  /// ```
  /// flutter run   --dart-define=ENABLE_QUICK_LOGIN=true
  /// docker compose  # compose 의 frontend build args 에서 true 로 지정돼 있다
  /// ```
  ///
  /// `kDebugMode` 를 쓰지 않는 이유: 컨테이너는 `--release` 로 빌드하는데
  /// 로컬 확인은 그 컨테이너(`http://localhost/`)로 하기 때문에,
  /// debug 여부로 가르면 정작 필요한 곳에서 안 보인다.
  static const bool enableQuickLogin = bool.fromEnvironment(
    'ENABLE_QUICK_LOGIN',
  );
}
