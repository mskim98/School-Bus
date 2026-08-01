import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_ride_event_repository.dart';
import '../domain/ride_event.dart';

/// 조회 키.
///
/// [serviceDate] 는 **운행 세션의 운행일**을 그대로 넣는다. `DateTime.now()` 를
/// 넣으면 초가 계속 바뀌어 키가 매번 달라지고, 3초 폴링마다 새 요청이 나간다.
typedef AdminBusRideEventsQuery = ({
  int tenantId,
  int busId,
  DateTime serviceDate,
});

/// 버스 한 대의 그날 승하차 기록.
///
/// ⚠️ **날짜 단위 응답이라 그날 등원·하원 기록이 섞여 온다.** 운행 한 편의 상태를
/// 세려면 세션 시작 시각 이후만 봐야 한다 — 그 계산은
/// `BusOperationStatus.of(...)` 가 한다. 여기서는 거르지 않는다(어느 세션 기준으로
/// 거를지는 조회하는 화면이 정한다).
final adminBusRideEventsProvider = FutureProvider.autoDispose
    .family<List<RideEvent>, AdminBusRideEventsQuery>((ref, query) {
      return ref
          .read(adminRideEventRepositoryProvider)
          .tenantRecords(
            tenantId: query.tenantId,
            busId: query.busId,
            from: query.serviceDate,
            to: query.serviceDate,
          );
    });
