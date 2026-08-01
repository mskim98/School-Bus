import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/routing_repository.dart';
import '../domain/route_plan.dart';

/// 조회 키. 레코드라 구조적 동등성이 있어 같은 버스면 캐시가 그대로 맞는다.
typedef AdminBusRouteQuery = ({int tenantId, int busId});

/// 버스 한 대의 **배포된(PUBLISHED) 노선** — 방향마다 최신 1건.
///
/// 왜 걸러서 주는가: `GET /api/route-plans` 는 상태와 무관하게 전부 준다. 배차를
/// 다시 돌릴 때마다 version 이 올라간 새 행이 쌓이므로(`RoutePlan.version` 주석),
/// 받은 대로 지도에 그리면 **같은 버스의 옛 노선이 여러 겹 겹쳐 그려진다.**
/// 관제가 알고 싶은 건 "지금 이 버스가 실제로 도는 길"이라 배포본만 남긴다.
///
/// 제안(RECOMMENDED)까지 그리지 않는 이유도 같다 — 아직 확정되지 않은 길을
/// 관제 지도에 그리면 관리자가 버스가 그 길로 간다고 읽는다. 제안을 보는 자리는
/// 배차 화면이다.
///
/// 결과는 **등원 → 하원** 순이다. 배포된 계획이 없으면 빈 목록이고, 그건 에러가
/// 아니다(컨벤션 §7-4) — 아직 배차하지 않은 버스일 뿐이다.
///
/// 관제 지도는 3초마다 위치를 다시 부르지만 노선은 그 주기로 바뀌지 않는다.
/// `family` 키가 버스라 **선택이 바뀔 때만** 실제 요청이 나간다.
final adminBusRoutePlansProvider = FutureProvider.autoDispose
    .family<List<RoutePlan>, AdminBusRouteQuery>((ref, query) async {
      final plans = await ref
          .read(routingRepositoryProvider)
          .getPlans(tenantId: query.tenantId, busId: query.busId);

      final latest = <RouteDirection, RoutePlan>{};
      for (final plan in plans) {
        if (!plan.status.isPublished) continue;
        final kept = latest[plan.direction];
        if (kept == null || _isNewer(plan, kept)) latest[plan.direction] = plan;
      }

      return [
        for (final direction in RouteDirection.values) ?latest[direction],
      ];
    });

/// 운행일이 늦은 쪽, 같으면 version 이 높은 쪽이 최신이다.
///
/// 서버 정렬을 믿지 않고 직접 고르는 이유: 여기서 어긋나면 관리자가 **어제 노선**을
/// 오늘 경로로 보게 된다. 정렬 규칙은 서버 구현에 딸린 것이라 언제든 바뀔 수 있다.
bool _isNewer(RoutePlan candidate, RoutePlan kept) {
  final byDate = candidate.serviceDate.compareTo(kept.serviceDate);
  if (byDate != 0) return byDate > 0;
  return candidate.version > kept.version;
}
