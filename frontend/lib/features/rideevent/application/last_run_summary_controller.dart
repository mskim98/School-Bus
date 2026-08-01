import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/ride_event_repository.dart';

/// 방금 끝낸 운행 한 건을 가리키는 키.
///
/// 세션 객체를 그대로 키로 쓰지 않는다 — `DriveSession` 은 `==` 를 정의하지 않아
/// 상태가 한 번 흔들릴 때마다 다른 키로 취급돼 같은 요청이 반복된다. 레코드는
/// 구조적 동등성을 가지므로 값이 같으면 캐시가 그대로 맞는다.
typedef LastRunQuery = ({
  int busId,
  DateTime serviceDate,
  DateTime startedAt,
  DateTime endedAt,
});

/// 끝난 운행 한 건의 **처리 건수**(그 구간에 기록된 승하차 건수).
///
/// 왜 다시 조회하는가 — 운행이 끝나면 명단이 비어서
/// (`DriveSessionController.end` 가 `roster` 를 비운다) `driverRosterControllerProvider`
/// 로는 셀 수 없다. 그렇다고 그 컨트롤러가 종료 후에도 기록을 들고 있게 만들면
/// **운행 중 화면의 상태에 종료 요약용 데이터가 섞인다** — 명단 화면이 쓰는 상태는
/// 승하차 기록의 단일 근거라서 요약 때문에 오염시키지 않는다.
///
/// 서버 이력은 **날짜 단위**라 그날 여러 편의 기록이 함께 온다. 그래서 세션 구간
/// (`startedAt ~ endedAt`)으로 한 번 더 걸러야 하원 편 요약에 등원 편 건수가
/// 얹히지 않는다.
///
/// 시간 비교는 양 끝을 포함한다. 마지막 하차를 기록한 직후 종료를 누르는 게
/// 정상 흐름이라, 종료 시각과 같은 초에 찍힌 기록을 빼면 그 한 건이 사라진다.
final lastRunProcessedCountProvider = FutureProvider.autoDispose
    .family<int, LastRunQuery>((ref, query) async {
      final events = await ref
          .read(rideEventRepositoryProvider)
          .busRecords(busId: query.busId, date: query.serviceDate);

      return events
          .where(
            (event) =>
                !event.occurredAt.isBefore(query.startedAt) &&
                !event.occurredAt.isAfter(query.endedAt),
          )
          .length;
    });
