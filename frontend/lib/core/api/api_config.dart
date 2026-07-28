/// 백엔드 접속 설정.
///
/// [apiBaseUrl] 은 빌드 시점에 주입한다:
///   flutter run   -d chrome --dart-define=API_BASE_URL=http://localhost:8080
///   flutter build web --dart-define=API_BASE_URL=https://api.example.com
///
/// 기본값이 컨테이너명(backend:8080)이 아니라 localhost:8080 인 이유 —
/// 이 앱은 브라우저에서 돌고, 요청 주체는 컨테이너가 아니라 사용자 브라우저다.
/// 또 localhost:3000 은 백엔드 CORS 허용 목록(app.cors.allowed-origins)에 이미 들어 있어
/// 개발 서버를 3000 포트로 띄우면 별도 설정 없이 붙는다.
class ApiConfig {
  const ApiConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// STOMP over WebSocket 엔드포인트. http→ws / https→wss 로 스킴만 바꾼다.
  /// SockJS 는 쓰지 않는다(백엔드가 순수 STOMP — MVP_API_SPEC §7.1).
  static String get wsUrl {
    final ws = apiBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return '$ws/ws/location';
  }
}
