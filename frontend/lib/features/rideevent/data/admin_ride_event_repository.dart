import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../domain/ride_event.dart';
import 'dto/ride_event_dto.dart';

/// 관리자용 승하차 기록 조회.
///
/// [RideEventRepository](ride_event_repository.dart) 의 `busRecords` 와 나눠 둔 이유는
/// **권한이 다르기 때문**이다. `GET /api/ride-events/bus/{busId}` 는 `hasRole('DRIVER')`
/// 라 관리자가 부르면 403 이고, 관리자에게 열린 건 학원 기간 조회 하나다.
class AdminRideEventRepository {
  const AdminRideEventRepository(this._client);

  final ApiClient _client;

  /// 학원의 기간 기록(`GET /api/ride-events`, 권한 `ACADEMY_ADMIN`·`PLATFORM_ADMIN`).
  ///
  /// ⚠️ **서버에 버스 필터가 없다.** 학원 전체가 오므로 [busId] 를 주면 응답의
  /// `busId` 로 여기서 걸러 준다. 거르는 자리를 경계(repository)에 두는 이유는
  /// 화면 모델인 [RideEvent] 가 버스 id 를 들고 있지 않기 때문이다 — 기사 화면은
  /// 애초에 자기 버스 기록만 받아서 필요가 없었다.
  ///
  /// ⚠️ [from]·[to] 는 **날짜 단위**다. 하루를 그대로 받으면 그날 등원·하원 기록이
  /// 함께 오므로, 운행 한 편을 보려면 세션 시작 시각으로 한 번 더 걸러야 한다
  /// (`RosterStudent.merge` 주석과 같은 함정이다).
  ///
  /// 빈 배열은 정상이다 — 아직 아무도 안 탔다는 뜻이다(컨벤션 §7-4).
  Future<List<RideEvent>> tenantRecords({
    int? tenantId,
    int? busId,
    required DateTime from,
    required DateTime to,
  }) async {
    final dtos = await _client.get(
      '/api/ride-events',
      query: {
        'tenantId': tenantId,
        'from': _formatDate(from),
        'to': _formatDate(to),
      },
      decode: Decode.list(RideEventDto.fromJson),
    );
    return [
      for (final dto in dtos)
        if (busId == null || dto.busId == busId)
          // 해석 못 하는 종류의 기록은 버린다 — 그 한 건 때문에 집계 전체가 죽지 않게.
          ?RideEvent.fromDto(dto),
    ];
  }

  /// 서버가 요구하는 `yyyy-MM-dd`.
  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

final adminRideEventRepositoryProvider = Provider<AdminRideEventRepository>(
  (ref) => AdminRideEventRepository(ref.watch(apiClientProvider)),
);
