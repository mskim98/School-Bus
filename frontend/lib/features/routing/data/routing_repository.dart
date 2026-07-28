import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../domain/auto_assign_result.dart';
import '../domain/route_plan.dart';
import 'dto/auto_assign_dto.dart';
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

  // ── 관리자 ──

  /// 관리자: 자동 배차 **제안**(C10). 아직 배정을 바꾸지 않는다 — [AutoAssignResult] 주석 참조.
  ///
  /// ⚠️ [tenantId] 는 학원 관리자도 **생략할 수 없다**(서버 `@NotNull`, 빠지면 400).
  /// `GET /api/route-plans` 의 선택 파라미터와 규칙이 다르니 헷갈리지 말 것.
  ///
  /// ⚠️ 이미 확정(PUBLISHED)된 계획이 있어도 **409 가 아니다.** 서버가 version 을 올린
  /// 새 RECOMMENDED 계획을 만들어 돌려준다(실호출 확인) — 기존 계획은 그대로 남는다.
  Future<AutoAssignResult> autoAssign({
    required int tenantId,
    required RouteDirection direction,
    DateTime? serviceDate,
  }) async {
    final request = AutoAssignRequestDto(
      tenantId: tenantId,
      direction: direction.wireName,
      serviceDate: serviceDate == null
          ? null
          : RoutePlan.formatDate(serviceDate),
    );
    final dto = await _client.post(
      '/api/route-plans/auto-assign',
      body: request.toJson(),
      decode: Decode.one(AutoAssignResponseDto.fromJson),
    );
    return AutoAssignResult.fromDto(dto);
  }

  /// 관리자: 제안 **확정**(C10). 학생 배정 커밋 + 승인 + 배포가 한 번에 처리된다.
  ///
  /// 이미 확정된 계획을 다시 보내면 **409** 다 — 화면은 버튼을 되살리지 말고
  /// 목록을 새로고침해야 한다(계획서 §3.2).
  Future<List<RoutePlan>> confirmAutoAssign({
    required List<int> planIds,
  }) async {
    final dtos = await _client.post(
      '/api/route-plans/auto-assign/confirm',
      body: ConfirmAutoAssignRequestDto(planIds: planIds).toJson(),
      decode: Decode.list(RoutePlanDto.fromJson),
    );
    return dtos.map(RoutePlan.fromDto).toList(growable: false);
  }

  /// 관리자: 노선 계획 목록(C11). [busId] 를 생략하면 학원 전체.
  ///
  /// 상태와 무관하게 전부 내려온다(제안·배포 섞여 있음) — 최신순 정렬은 서버가 한다.
  Future<List<RoutePlan>> getPlans({required int tenantId, int? busId}) async {
    final dtos = await _client.get(
      '/api/route-plans',
      query: {'tenantId': tenantId, 'busId': busId},
      decode: Decode.list(RoutePlanDto.fromJson),
    );
    return dtos.map(RoutePlan.fromDto).toList(growable: false);
  }

  /// 관리자: 노선 계획 상세(C11) — 정차 순서 `stops[]` 포함.
  Future<RoutePlan> getPlan(int planId) async {
    final dto = await _client.get(
      '/api/route-plans/$planId',
      decode: Decode.one(RoutePlanDto.fromJson),
    );
    return RoutePlan.fromDto(dto);
  }

  /// 서버가 기대하는 `yyyy-MM-dd`.
  static String? _formatDate(DateTime? date) =>
      date == null ? null : RoutePlan.formatDate(date);
}

final routingRepositoryProvider = Provider<RoutingRepository>(
  (ref) => RoutingRepository(ref.watch(apiClientProvider)),
);
