import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_response.dart';
import '../domain/my_bus.dart';
import 'dto/bus_dto.dart';
import 'dto/my_bus_dto.dart';

/// 기사 담당 버스 조회.
///
/// 서버가 하나뿐이고 교체 계획이 없어 포트로 나누지 않는다(컨벤션 §5).
///
/// 📌 `auth/data/auth_repository.dart` 의 `fetchMyBusId()` 가 같은 엔드포인트를
/// 부르지만 그건 **로그인 직후 세션을 완성하는 단계**라 busId 하나만 뽑는다
/// (`MVP_API_SPEC.md` §2.3). 여기는 화면이 쓰는 버스 정보를 받는 쪽이다.
/// 둘을 합치면 auth 가 bus feature 를 import 해야 해서 의존이 생긴다(컨벤션 C-1).
class BusRepository {
  const BusRepository(this._client);

  final ApiClient _client;

  /// 기사 본인의 담당 버스(`GET /api/buses/me`, 권한 `DRIVER`).
  ///
  /// 담당 버스가 없으면 서버가 **404** 를 준다. 그건 오류가 아니라 "아직 배차
  /// 안 됨"이라는 정상 상태라 예외로 올리지 않고 null 로 접는다 —
  /// `auth_repository.fetchMyBusId()` 와 같은 처리다.
  Future<MyBus?> findMyBus() async {
    try {
      final dto = await _client.get(
        '/api/buses/me',
        decode: Decode.one(MyBusDto.fromJson),
      );
      return MyBus.fromDto(dto);
    } on ApiException catch (e) {
      if (e.kind == ApiErrorKind.notFound) return null;
      rethrow;
    }
  }

  /// 학원의 버스 목록(`GET /api/buses`, 권한 `ACADEMY_ADMIN`·`PLATFORM_ADMIN`).
  ///
  /// 📌 `location/data/location_repository.dart` 의 `getBuses()` 가 같은
  /// 엔드포인트를 부르지만 그건 **관제 지도가 위치와 합칠 요약**만 담는다
  /// (`BusSummaryDto`). 여기는 정원·배정 인원까지 필요한 쪽이라 DTO 가 다르다.
  /// 하나로 합치려면 `shared/` 로 올려야 하는데, 그러면 `location` 의 기존 화면이
  /// 안 쓰는 필드까지 파싱하게 된다.
  Future<List<BusDto>> list({required int tenantId}) {
    return _client.get(
      '/api/buses',
      query: {'tenantId': tenantId},
      decode: Decode.list(BusDto.fromJson),
    );
  }
}

final busRepositoryProvider = Provider<BusRepository>(
  (ref) => BusRepository(ref.watch(apiClientProvider)),
);
