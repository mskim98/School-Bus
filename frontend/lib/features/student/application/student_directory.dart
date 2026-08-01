import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dto/student_dto.dart';
import '../data/student_repository.dart';

/// `studentId → 이름` 을 찾아주는 명부.
///
/// **왜 따로 두는가** — 배차 제안도 노선 계획도 `studentId` 만 준다. 화면마다
/// `GET /api/students` 를 부르면 같은 목록을 여러 번 받고, 응답 시점이 어긋나
/// 한 화면 안에서 어떤 줄은 이름이 뜨고 어떤 줄은 `#7` 로 남는다. 한 번 받아
/// 공유한다.
///
/// 이름을 못 찾았을 때 **빈 문자열이나 `학생`으로 얼버무리지 않는다** — `#7` 은
/// "이 학생이 누군지 아직 모른다"는 사실을 그대로 드러내는 표기다. 그래야
/// 관리자가 명부가 덜 불러와진 상태를 배정 오류로 오해하지 않는다.
class StudentDirectory {
  const StudentDirectory(this._byId);

  const StudentDirectory.empty() : this(const {});

  final Map<int, StudentDto> _byId;

  bool get isEmpty => _byId.isEmpty;

  StudentDto? find(int studentId) => _byId[studentId];

  /// 화면에 그대로 쓰는 표기. 모르면 `#id`.
  String nameOf(int studentId) => _byId[studentId]?.name ?? '#$studentId';

  /// 여러 명을 순서 그대로 이름으로 바꾼다.
  List<String> namesOf(Iterable<int> studentIds) => [
    for (final id in studentIds) nameOf(id),
  ];

  static StudentDirectory fromList(List<StudentDto> students) =>
      StudentDirectory({for (final s in students) s.id: s});
}

/// 학원 하나의 학생 명부. 학원이 바뀌면 자동으로 다시 받는다.
final studentDirectoryProvider = FutureProvider.family<StudentDirectory, int>((
  ref,
  tenantId,
) async {
  final students = await ref
      .read(studentRepositoryProvider)
      .list(tenantId: tenantId);
  return StudentDirectory.fromList(students);
});
