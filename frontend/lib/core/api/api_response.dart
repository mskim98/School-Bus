/// 백엔드 공통 응답 봉투 — 모든 REST 응답이 이 한 가지 모양으로 온다.
///
/// ```json
/// { "success": true,  "data": { ... }, "message": null }
/// { "success": false, "data": null,    "message": "사람이 읽는 한글 메시지" }
/// ```
///
/// 화면은 이 타입을 직접 다루지 않는다 — [ApiClient] 가 벗겨서 `data` 만 돌려주고,
/// 실패면 [ApiException] 을 던진다. 이 클래스를 따로 두는 이유는 "서버 계약이 이렇게
/// 생겼다"를 코드로 남기고 단위 테스트로 고정하기 위해서다.
class ApiResponse<T> {
  const ApiResponse({required this.success, this.data, this.message});

  final bool success;
  final T? data;

  /// 사용자에게 **그대로 보여주는** 문구. 이 문자열로 분기하지 않는다(컨벤션 §7-1).
  final String? message;

  /// [decode] 는 `data` 필드(Object?)를 원하는 타입으로 바꾸는 함수다.
  /// 성공이 아니거나 `data` 가 null 이면 [decode] 를 호출하지 않는다 —
  /// 실패 응답의 `data` 는 항상 null 이라 파싱을 시도할 이유가 없다.
  static ApiResponse<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Object? data) decode,
  ) {
    final success = json['success'] == true;
    final raw = json['data'];
    return ApiResponse<T>(
      success: success,
      data: (success && raw != null) ? decode(raw) : null,
      message: json['message'] as String?,
    );
  }
}

/// `data` 디코더 모음. repository 가 `decode:` 인자로 넘겨 쓴다.
///
/// 서버 필드명을 화면에서 문자열 키로 직접 뒤지는 걸 막기 위한 장치다(컨벤션 §8) —
/// JSON → 타입 변환은 반드시 이 경계에서 끝낸다.
class Decode {
  const Decode._();

  /// 본문이 없는 응답(`data: null`). 예) 위치 보고
  static void unit(Object? _) {}

  /// 객체 하나 → 모델 하나
  static T Function(Object?) one<T>(T Function(Map<String, dynamic>) fromJson) {
    return (data) => fromJson(_asMap(data));
  }

  /// 배열 → 모델 목록. 빈 배열은 정상이다(에러 아님, 컨벤션 §7-4).
  static List<T> Function(Object?) list<T>(
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return (data) {
      if (data is! List) {
        throw FormatException('배열을 기대했지만 ${data.runtimeType} 를 받았습니다');
      }
      return data.map((e) => fromJson(_asMap(e))).toList(growable: false);
    };
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw FormatException('객체를 기대했지만 ${value.runtimeType} 를 받았습니다');
  }
}
