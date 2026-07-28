/// 어떤 [LocationSource] 를 쓸지 고르는 값. 기사 화면의 토글이 이걸 바꾼다.
///
/// enum 을 따로 둔 이유: 화면이 구현체 타입(`MockLocationSource`)을 알면 `core/*/impl`
/// 을 직접 참조하게 되어 포트 규칙이 깨진다(컨벤션 §5, 검사 C-5).
enum LocationSourceKind {
  /// 노선 경로를 따라 좌표를 만들어낸다. **기본값** — 위치 권한 없이 전 흐름을 시연한다.
  mock('Mock', '노선을 따라 이동하는 가상 좌표'),

  /// 단말의 실제 GPS. 실기기 검증용.
  gps('실 GPS', '단말 위치 권한이 필요합니다');

  const LocationSourceKind(this.label, this.description);

  final String label;
  final String description;
}
