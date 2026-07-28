/// 앱 전역 API 예외. 화면·상태 계층은 `DioException` 을 절대 보지 않는다 —
/// dio 는 [ApiClient] 안에 갇혀 있고, 밖으로는 이 타입만 나간다(컨벤션 §3).
///
/// ⚠️ **분기는 [kind](= HTTP status)로만 한다.** 백엔드 실패 응답에는
/// `errorCode` 같은 기계판독용 필드가 없어서, [message] 문자열을 비교해 분기하면
/// 서버가 문구만 다듬어도 앱이 조용히 깨진다(컨벤션 §7-1).
library;

/// HTTP status 를 앱이 다룰 갈래로 접은 것.
///
/// 백엔드 공통 에러표(MVP_API_SPEC §1.3)와 1:1 대응한다.
enum ApiErrorKind {
  /// 400 — 입력값 오류. 폼 필드 밑에 [ApiException.message] 를 그대로 띄운다.
  badRequest,

  /// 401 — 미인증/토큰 만료. refresh 후 재시도, 실패하면 로그인 화면으로.
  unauthorized,

  /// 403 — 권한 없음. "역할 불일치"와 "담당·소속 아님" 두 경우가 같은 403이라 구분 불가.
  forbidden,

  /// 404 — 대상 없음. 빈 상태 UI 로 처리한다.
  notFound,

  /// 409 — 이미 처리됨. 버튼을 다시 살리지 말고 목록을 새로고침한다.
  conflict,

  /// 5xx — 서버 오류.
  server,

  /// 연결 실패·타임아웃. 서버가 응답을 못 준 경우라 status 가 없다.
  network,

  /// 그 밖(응답 형식이 계약과 다름 등).
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  final ApiErrorKind kind;

  /// 사용자에게 보여줄 문구. 서버가 준 `message` 를 우선 쓰고, 없으면 갈래별 기본값.
  final String message;

  /// 서버가 응답을 준 경우에만 존재한다([ApiErrorKind.network] 이면 null).
  final int? statusCode;

  /// HTTP status → 예외. [serverMessage] 가 비어 있으면 갈래별 기본 문구를 쓴다.
  factory ApiException.fromStatus(int? statusCode, [String? serverMessage]) {
    final kind = _kindOf(statusCode);
    final message = (serverMessage != null && serverMessage.trim().isNotEmpty)
        ? serverMessage
        : _defaultMessageOf(kind);
    return ApiException(kind: kind, message: message, statusCode: statusCode);
  }

  /// 서버에 닿지 못한 경우(연결 거부·타임아웃·DNS 실패 등).
  factory ApiException.network([String? message]) => ApiException(
    kind: ApiErrorKind.network,
    message: message ?? '서버에 연결할 수 없습니다. 네트워크 상태를 확인해 주세요',
  );

  /// 계약과 다른 응답을 받은 경우. 서버가 200 을 줬어도 파싱이 안 되면 여기로 온다.
  factory ApiException.malformed([String? detail]) => ApiException(
    kind: ApiErrorKind.unknown,
    message: detail == null ? '응답을 해석할 수 없습니다' : '응답을 해석할 수 없습니다 ($detail)',
  );

  /// 토큰 재발급으로 회복을 시도해볼 수 있는가 — 인터셉터(C4)가 이 값을 본다.
  bool get isRetriableWithRefresh => kind == ApiErrorKind.unauthorized;

  static ApiErrorKind _kindOf(int? statusCode) {
    if (statusCode == null) return ApiErrorKind.unknown;
    if (statusCode >= 500) return ApiErrorKind.server;
    return switch (statusCode) {
      400 => ApiErrorKind.badRequest,
      401 => ApiErrorKind.unauthorized,
      403 => ApiErrorKind.forbidden,
      404 => ApiErrorKind.notFound,
      409 => ApiErrorKind.conflict,
      _ => ApiErrorKind.unknown,
    };
  }

  static String _defaultMessageOf(ApiErrorKind kind) => switch (kind) {
    ApiErrorKind.badRequest => '입력값이 올바르지 않습니다',
    ApiErrorKind.unauthorized => '인증이 필요합니다',
    ApiErrorKind.forbidden => '접근 권한이 없습니다',
    ApiErrorKind.notFound => '대상을 찾을 수 없습니다',
    ApiErrorKind.conflict => '이미 처리된 요청입니다',
    ApiErrorKind.server => '서버 오류가 발생했습니다',
    ApiErrorKind.network => '서버에 연결할 수 없습니다',
    ApiErrorKind.unknown => '알 수 없는 오류가 발생했습니다',
  };

  @override
  String toString() => 'ApiException($kind, status=$statusCode): $message';
}
