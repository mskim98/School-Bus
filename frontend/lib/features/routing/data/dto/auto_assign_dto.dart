import 'route_plan_dto.dart';

/// `POST /api/route-plans/auto-assign` 요청 본문.
///
/// ⚠️ **`tenantId` 는 학원 관리자도 생략할 수 없다.** 서버 `AutoAssignRequest` 의
/// `@NotNull` 이라 빠지면 400 이다(`GET /api/route-plans` 의 선택 파라미터와 다르다).
/// 실호출로 확인: 본문에서 빼면 `400 "tenantId: must not be null"`.
class AutoAssignRequestDto {
  const AutoAssignRequestDto({
    required this.tenantId,
    required this.direction,
    this.serviceDate,
  });

  final int tenantId;

  /// `PICKUP` / `DROPOFF`
  final String direction;

  /// `yyyy-MM-dd`. 생략하면 서버가 오늘로 처리한다.
  final String? serviceDate;

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'direction': direction,
    // null 을 실어 보내면 서버 날짜 파싱이 400 을 낸다 — 아예 키를 빼야 기본값이 적용된다.
    if (serviceDate != null) 'serviceDate': serviceDate,
  };
}

/// `POST /api/route-plans/auto-assign` 응답 `data`.
///
/// ⚠️ [excludedStudentNames] 는 **에러가 아니라 정상 응답의 일부**다.
/// 승하차 좌표가 없어 배정에서 빠진 학생 이름이며, 화면이 이걸 안 보여주면
/// 관리자가 학생 누락을 모른 채 확정하게 된다.
class AutoAssignResponseDto {
  const AutoAssignResponseDto({
    required this.plans,
    required this.excludedStudentNames,
  });

  final List<RoutePlanDto> plans;
  final List<String> excludedStudentNames;

  static AutoAssignResponseDto fromJson(Map<String, dynamic> json) =>
      AutoAssignResponseDto(
        plans: ((json['plans'] as List?) ?? const [])
            .map((e) => RoutePlanDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        excludedStudentNames:
            ((json['excludedStudentNames'] as List?) ?? const [])
                .map((e) => e.toString())
                .toList(growable: false),
      );
}

/// `POST /api/route-plans/auto-assign/confirm` 요청 본문.
class ConfirmAutoAssignRequestDto {
  const ConfirmAutoAssignRequestDto({required this.planIds});

  /// 확정할 계획 id 목록. 서버가 `minItems: 1` 을 요구한다.
  final List<int> planIds;

  Map<String, dynamic> toJson() => {'planIds': planIds};
}
