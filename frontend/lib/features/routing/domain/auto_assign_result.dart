import '../data/dto/auto_assign_dto.dart';
import 'route_plan.dart';

/// 자동 배차 **제안** 결과.
///
/// DTO 를 그대로 쓰지 않는 이유(컨벤션 §4): 안에 든 계획들이 `polyline` 파싱을 거쳐야
/// 지도에 그려지고, 그 변환은 [RoutePlan] 이 담당한다.
///
/// ⚠️ **이 시점엔 학생 배정이 아직 바뀌지 않았다.** 서버는 `RECOMMENDED` 계획만
/// 만들어 두고, 실제 배정 커밋·승인·배포는 확정(`confirm`) 때 한꺼번에 일어난다.
class AutoAssignResult {
  const AutoAssignResult({
    required this.plans,
    required this.excludedStudentNames,
  });

  final List<RoutePlan> plans;

  /// 승하차 좌표가 없어 **배정에서 빠진** 학생 이름. 비어 있는 게 정상이다.
  final List<String> excludedStudentNames;

  bool get isEmpty => plans.isEmpty;

  bool get hasExcludedStudents => excludedStudentNames.isNotEmpty;

  /// 제안에 포함된 전체 정차 수 = 실제로 배정된 학생 수.
  int get totalStops => plans.fold(0, (sum, plan) => sum + plan.stops.length);

  /// 확정 요청에 실어 보낼 계획 id.
  ///
  /// 이미 배포된 계획을 섞어 보내면 서버가 **409** 로 전부 거절하므로
  /// 확정 가능한 단계의 것만 추린다([RoutePlanStatus.isConfirmable]).
  List<int> get confirmablePlanIds => plans
      .where((plan) => plan.status.isConfirmable)
      .map((plan) => plan.id)
      .toList(growable: false);

  static AutoAssignResult fromDto(AutoAssignResponseDto dto) =>
      AutoAssignResult(
        plans: dto.plans.map(RoutePlan.fromDto).toList(growable: false),
        excludedStudentNames: dto.excludedStudentNames,
      );
}
