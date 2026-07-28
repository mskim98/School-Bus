import '../../map/spec/map_view_adapter.dart';

/// 기사 단말의 "지금 좌표"를 얻는 포트.
///
/// 포트로 둔 이유(컨벤션 §5, 계획서 §8 D2): MVP 시연은 위치 권한·개인정보 동의 없이
/// 브라우저에서 돌아가야 하고, 실기기 검증은 진짜 GPS 로 해야 한다. 두 요구를 한
/// 구현으로 만족시킬 수 없으므로 구현체를 갈아끼운다.
/// 백엔드의 `LocationSource` 포트(`MockBusLocationSource` / 실 GPS push)와 대칭이다.
///
/// **pull 방식(스트림이 아님)인 이유**: 전송 주기를 정하는 주체가 앱(5초)이지 단말이
/// 아니다. 스트림으로 두면 "언제 보낼지"가 구현체마다 달라져 주기를 한 곳에서 못 바꾼다.
abstract interface class LocationSource {
  /// 다음 좌표 하나. 좌표를 만들 수 없으면 [LocationUnavailableException] 를 던진다.
  ///
  /// ⚠️ 구현체가 **호출될 때마다 상태를 전진시켜도 된다**(Mock 은 경로를 따라 이동한다).
  /// 같은 좌표를 두 번 읽는 용도로 쓰지 말 것.
  Future<GeoPoint> read();
}

/// 좌표를 얻을 수 없는 상태 — 위치 권한 거부, 단말 위치 서비스 꺼짐, Mock 경로 없음 등.
///
/// [ApiException] 과 달리 **서버에 닿기 전에** 발생한다. 재시도해도 사용자가 설정을
/// 바꾸기 전까지는 같은 결과라, 받는 쪽은 전송을 멈추고 [message] 를 그대로 보여준다.
class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.message);

  /// 사용자에게 **그대로 보여주는** 문구(컨벤션 §7-2).
  final String message;

  @override
  String toString() => 'LocationUnavailableException: $message';
}
