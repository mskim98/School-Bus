import 'package:flutter_test/flutter_test.dart';
import 'package:school_bus/features/routing/data/dto/auto_assign_dto.dart';
import 'package:school_bus/features/routing/domain/auto_assign_result.dart';
import 'package:school_bus/features/routing/domain/route_plan_status.dart';

/// 실제 `POST /api/route-plans/auto-assign` 응답 모양(2026-07-28 실호출 확인).
Map<String, dynamic> planJson({
  required int id,
  required int busId,
  String status = 'RECOMMENDED',
  int version = 1,
  List<Map<String, dynamic>> stops = const [],
}) => {
  'id': id,
  'tenantId': 1,
  'busId': busId,
  'direction': 'DROPOFF',
  'status': status,
  'version': version,
  'serviceDate': '2026-07-28',
  'totalDistanceM': 4618.0,
  'totalDurationS': 1367.798,
  'polyline': '[[127.0354531,37.5075808],[127.031,37.5045]]',
  'stops': stops,
};

Map<String, dynamic> stopJson(int seq, int studentId) => {
  'seq': seq,
  'studentId': studentId,
  'lat': 37.506,
  'lng': 127.029,
  'etaSeconds': 292,
};

void main() {
  group('AutoAssignResponseDto — 서버 계약', () {
    test('제외 학생 이름이 있으면 그대로 담는다 ★', () {
      // 하원 배차 실호출에서 실제로 3명이 빠졌다(하원 좌표 미등록).
      final dto = AutoAssignResponseDto.fromJson({
        'plans': [
          planJson(id: 3, busId: 1, stops: [stopJson(1, 3), stopJson(2, 1)]),
        ],
        'excludedStudentNames': ['최지우', '정하율', '강서준'],
      });

      final result = AutoAssignResult.fromDto(dto);

      expect(result.excludedStudentNames, hasLength(3));
      expect(result.hasExcludedStudents, isTrue, reason: '배너를 띄울 근거');
    });

    test('제외 학생이 없으면 빈 목록 — 에러가 아니다', () {
      final dto = AutoAssignResponseDto.fromJson({
        'plans': [planJson(id: 2, busId: 1)],
        'excludedStudentNames': <String>[],
      });

      expect(AutoAssignResult.fromDto(dto).hasExcludedStudents, isFalse);
    });

    test('키 자체가 빠져도 죽지 않는다', () {
      final result = AutoAssignResult.fromDto(
        AutoAssignResponseDto.fromJson(const {}),
      );

      expect(result.plans, isEmpty);
      expect(result.excludedStudentNames, isEmpty);
      expect(result.isEmpty, isTrue);
    });

    test('계획 안의 polyline 도 좌표로 풀린다 — 지도가 바로 그릴 수 있어야 한다', () {
      final result = AutoAssignResult.fromDto(
        AutoAssignResponseDto.fromJson({
          'plans': [planJson(id: 2, busId: 1)],
          'excludedStudentNames': <String>[],
        }),
      );

      final path = result.plans.single.path;
      expect(path, hasLength(2));
      expect(path.first.lat, 37.5075808, reason: '[lng, lat] 를 뒤집어 담는다');
    });
  });

  group('확정 대상 추리기 ★', () {
    test('RECOMMENDED 만 확정 대상이다 — 이미 배포된 계획을 섞어 보내면 서버가 409 로 전부 거절한다', () {
      final result = AutoAssignResult.fromDto(
        AutoAssignResponseDto.fromJson({
          'plans': [
            planJson(id: 2, busId: 1, status: 'RECOMMENDED'),
            planJson(id: 1, busId: 2, status: 'PUBLISHED'),
            planJson(id: 4, busId: 3, status: 'APPROVED'),
          ],
          'excludedStudentNames': <String>[],
        }),
      );

      expect(result.confirmablePlanIds, [2]);
    });

    test('확정 가능한 계획이 하나도 없으면 빈 목록 — 화면이 버튼을 막는 근거', () {
      final result = AutoAssignResult.fromDto(
        AutoAssignResponseDto.fromJson({
          'plans': [planJson(id: 1, busId: 1, status: 'PUBLISHED')],
          'excludedStudentNames': <String>[],
        }),
      );

      expect(result.confirmablePlanIds, isEmpty);
    });

    test('배정 학생 수 = 전체 정차 수', () {
      final result = AutoAssignResult.fromDto(
        AutoAssignResponseDto.fromJson({
          'plans': [
            planJson(id: 2, busId: 1, stops: [stopJson(1, 3), stopJson(2, 1)]),
            planJson(id: 3, busId: 2, stops: [stopJson(1, 5)]),
          ],
          'excludedStudentNames': <String>[],
        }),
      );

      expect(result.totalStops, 3);
    });
  });

  group('요청 본문', () {
    test('serviceDate 를 안 고르면 키 자체를 뺀다 — null 을 실어 보내면 서버가 400 이다', () {
      const request = AutoAssignRequestDto(tenantId: 1, direction: 'PICKUP');

      expect(request.toJson(), {'tenantId': 1, 'direction': 'PICKUP'});
      expect(request.toJson().containsKey('serviceDate'), isFalse);
    });

    test('고른 날짜는 yyyy-MM-dd 로 실린다', () {
      const request = AutoAssignRequestDto(
        tenantId: 1,
        direction: 'DROPOFF',
        serviceDate: '2026-07-29',
      );

      expect(request.toJson()['serviceDate'], '2026-07-29');
    });

    test('확정 요청은 planIds 만 보낸다', () {
      const request = ConfirmAutoAssignRequestDto(planIds: [2, 3]);

      expect(request.toJson(), {
        'planIds': [2, 3],
      });
    });
  });

  group('RoutePlanStatus', () {
    test('DRAFT·RECOMMENDED 만 확정할 수 있다', () {
      expect(RoutePlanStatus.draft.isConfirmable, isTrue);
      expect(RoutePlanStatus.recommended.isConfirmable, isTrue);
      expect(RoutePlanStatus.approved.isConfirmable, isFalse);
      expect(RoutePlanStatus.published.isConfirmable, isFalse);
    });

    test('모르는 상태 값이 와도 null 을 돌려줄 뿐 죽지 않는다', () {
      expect(RoutePlanStatus.fromWire('FUTURE_STATUS'), isNull);
      expect(RoutePlanStatus.fromWire(null), isNull);
      expect(RoutePlanStatus.fromWire('PUBLISHED'), RoutePlanStatus.published);
    });
  });
}
