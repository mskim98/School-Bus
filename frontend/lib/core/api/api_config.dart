/// 백엔드 접속 설정.
///
/// [apiBaseUrl] 은 빌드 시점에 주입한다:
/// ```
/// # 프록시 경유(기본, docker compose) — 같은 출처라 호스트를 붙일 필요가 없다
/// flutter build web --dart-define=API_BASE_URL=
///
/// # 프록시 없이 백엔드에 직접 붙을 때(로컬 flutter run, 모바일 실기기)
/// flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
/// ```
class ApiConfig {
  const ApiConfig._();

  /// 비어 있으면 **현재 출처**로 요청한다(상대 경로).
  ///
  /// docker compose 구성에서는 nginx 프록시가 `/` 와 `/api` 를 같은 :80 뒤에 두므로
  /// 호스트를 박아둘 이유가 없다. 비워두면 같은 번들이 localhost 에서도 배포
  /// 도메인에서도 그대로 동작하고, 출처가 같아 CORS 도 발생하지 않는다.
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// STOMP over WebSocket 엔드포인트.
  ///
  /// ⚠️ WebSocket 은 상대 경로를 못 쓴다 — 반드시 `ws://host:port/...` 형태여야 한다.
  /// 그래서 [apiBaseUrl] 이 비어 있으면 **현재 페이지 주소**([Uri.base])에서 유도한다.
  /// https 로 서비스하면 자동으로 `wss` 가 된다(브라우저가 http 페이지의 ws 를 막는다).
  static String get wsUrl {
    final base = apiBaseUrl.isEmpty ? Uri.base : Uri.parse(apiBaseUrl);
    return Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/ws/location',
    ).toString();
  }
}
