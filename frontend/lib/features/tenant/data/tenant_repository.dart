import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_response.dart';
import 'dto/tenant_dto.dart';

/// 학원 조회.
///
/// 서버가 하나뿐이고 교체 계획이 없어 포트로 나누지 않는다(컨벤션 §5).
class TenantRepository {
  const TenantRepository(this._client);

  final ApiClient _client;

  /// 학원 목록(`GET /api/tenants`, 권한 **`PLATFORM_ADMIN` 전용**).
  ///
  /// 학원 관리자가 부르면 403 이다. 그건 오류라기보다 "이 계정은 소속 학원 하나만
  /// 본다"는 뜻이라, 호출부가 예외를 다루지 않아도 되게 **빈 목록**으로 접는다 —
  /// 학원 선택 UI 는 목록이 비면 알아서 사라진다.
  Future<List<TenantDto>> list() async {
    try {
      return await _client.get(
        '/api/tenants',
        decode: Decode.list(TenantDto.fromJson),
      );
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.forbidden) return const [];
      rethrow;
    }
  }
}

final tenantRepositoryProvider = Provider<TenantRepository>(
  (ref) => TenantRepository(ref.watch(apiClientProvider)),
);
