import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import 'dto/student_dto.dart';

/// 학생 조회(관리자). 서버가 하나뿐이라 포트로 나누지 않는다(컨벤션 §5).
class StudentRepository {
  const StudentRepository(this._client);

  final ApiClient _client;

  /// 학원의 학생 목록(`GET /api/students`).
  Future<List<StudentDto>> list({required int tenantId}) {
    return _client.get(
      '/api/students',
      query: {'tenantId': tenantId},
      decode: Decode.list(StudentDto.fromJson),
    );
  }
}

final studentRepositoryProvider = Provider<StudentRepository>(
  (ref) => StudentRepository(ref.watch(apiClientProvider)),
);
