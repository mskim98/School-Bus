import '../data/dto/my_bus_dto.dart';

/// 기사가 오늘 모는 버스. 화면이 쓰는 모델.
///
/// DTO 를 그대로 안 쓰는 이유(컨벤션 §4): 서버가 주는 값이 비거나 없을 때
/// **뭐라고 표시할지**를 화면마다 따로 정하면 같은 버스가 앱바 부제와 운행 시작
/// 카드에서 다른 이름으로 나온다. 표기 결정을 여기 한 곳에 모은다.
class MyBus {
  const MyBus({
    required this.id,
    required this.seatCapacity,
    required this.assignedCount,
    this.name,
    this.plateNumber,
    this.routeName,
  });

  final int id;
  final String? name;
  final String? plateNumber;

  /// 물리 좌석 수(`정원 25석`).
  final int seatCapacity;

  /// 이 버스에 배정된 학생 수.
  ///
  /// 서버 필드명(`onboard`)을 그대로 안 쓴다 — "지금 탑승 중"으로 읽히는 이름인데
  /// 실제로는 배정 명부의 크기다. 이름을 물려받으면 화면이 현재 탑승 인원으로
  /// 착각해 그리고, 그건 기사가 잔류 학생을 판단하는 숫자와 섞인다.
  final int assignedCount;

  final String? routeName;

  /// 화면에 쓰는 호차명. 서버 `name` 이 비면 id 로 만든다.
  ///
  /// 빈 문자열을 그대로 그리면 카드 제목 자리가 통째로 비어서 기사가 "아직 로딩
  /// 중"으로 읽는다. `3호차` 는 지어낸 값이 아니라 id 를 표기로 옮긴 것뿐이다.
  String get displayName {
    final name = this.name?.trim();
    return (name == null || name.isEmpty) ? '$id호차' : name;
  }

  /// 차량번호. 없거나 비면 null — 빈 자리에 `-` 를 채우지 않는다.
  String? get plateLabel => _presence(plateNumber);

  /// 배정된 노선명. 없으면 null.
  ///
  /// "노선 미배정"과 "이름이 빈 노선"을 화면이 구별할 수 있어야 해서
  /// 빈 문자열을 null 로 접는다.
  String? get routeLabel => _presence(routeName);

  /// 앱바 부제에 쓰는 조각들(`3호차 · 하원 A노선`).
  ///
  /// 없는 값은 조각 자체가 빠진다. 자리를 `-` 로 채우면 `3호차 · - ` 가 되어
  /// "노선이 아직 없다"인지 "이름 없는 노선에 배정됐다"인지 알 수 없다.
  List<String> get titleParts => [displayName, ?routeLabel];

  static MyBus fromDto(MyBusDto dto) => MyBus(
    id: dto.id,
    seatCapacity: dto.seatCapacity,
    assignedCount: dto.onboard,
    name: dto.name,
    plateNumber: dto.plateNumber,
    routeName: dto.routeName,
  );

  static String? _presence(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
