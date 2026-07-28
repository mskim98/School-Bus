import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../domain/route_plan.dart';
import 'dto/route_plan_dto.dart';

/// 노선(배차 계획) 조회.
///
/// 서버가 하나뿐이고 교체 계획이 없어 포트로 나누지 않는다(컨벤션 §5).
class RoutingRepository {
  const RoutingRepository(this._client);

  final ApiClient _client;

  /// 기사의 그날 **배포 완료(PUBLISHED)** 노선. 등원/하원 방향순으로 온다.
  ///
  /// [serviceDate] 를 생략하면 서버가 오늘로 처리한다 — null 인 쿼리는
  /// [ApiClient] 가 알아서 떼므로 `?serviceDate=null` 로 나가지 않는다.
  ///
  /// 배포된 노선이 없으면 **빈 목록**이다(에러 아님).
  Future<List<RoutePlan>> getDriverPlans({
    required int busId,
    DateTime? serviceDate,
  }) async {
    final dtos = await _client.get(
      '/api/route-plans/driver/$busId',
      query: {'serviceDate': _formatDate(serviceDate)},
      decode: Decode.list(RoutePlanDto.fromJson),
    );
    return dtos.map(RoutePlan.fromDto).toList(growable: false);
  }

  /// 서버가 기대하는 `yyyy-MM-dd`.
  static String? _formatDate(DateTime? date) {
    if (date == null) return null;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

final routingRepositoryProvider = Provider<RoutingRepository>(
  (ref) => RoutingRepository(ref.watch(apiClientProvider)),
);
