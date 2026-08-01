/// `GET /api/students` 응답의 한 줄(권한 `ACADEMY_ADMIN`·`PLATFORM_ADMIN`).
///
/// **관리자 화면이 학생 이름을 얻는 유일한 경로다.** 노선 계획(`stops[]`)도
/// 배차 제안도 `studentId` 만 주므로, 이름을 붙이려면 이 목록과 맞춰야 한다
/// (기사 앱은 운행 세션 명단에서 이름을 받지만 그건 `DRIVER` 전용이다).
class StudentDto {
  const StudentDto({
    required this.id,
    required this.name,
    this.assignedBusId,
    this.dropoffAddress,
  });

  final int id;
  final String name;

  /// 지금 배정된 버스. 배차 확정 전에는 null 일 수 있다.
  final int? assignedBusId;

  /// 하차지 주소. 좌표가 없으면 배차에서 제외되므로 화면이 근거로 쓴다.
  final String? dropoffAddress;

  static StudentDto fromJson(Map<String, dynamic> json) => StudentDto(
    id: json['id'] as int,
    name: json['name'] as String,
    assignedBusId: json['assignedBusId'] as int?,
    dropoffAddress: json['dropoffAddress'] as String?,
  );
}
