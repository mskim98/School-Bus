import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_drive_session_repository.dart';
import '../domain/drive_session.dart';

/// 조회 키. 레코드를 쓰는 이유는 **구조적 동등성** 때문이다 —
/// 같은 학원·같은 버스면 캐시가 그대로 맞아 화면이 다시 그려져도 재요청하지 않는다.
typedef AdminBusSessionQuery = ({int tenantId, int busId});

/// 버스 한 대의 **가장 최근 운행 세션**. 이력이 없으면 null.
///
/// 관제 지도가 3초마다 위치를 다시 부르는 화면이라 **여기까지 3초마다 따라
/// 부르면 안 된다.** `family` 키가 버스 id 라 선택이 바뀔 때만 실제 요청이 나가고,
/// 폴링으로 위젯이 다시 그려지는 동안에는 캐시가 그대로 쓰인다.
///
/// `autoDispose` 인 이유: 선택을 해제하면 값을 버려야 다음에 그 버스를 다시 골랐을 때
/// 새로 받는다. 운행은 화면을 보는 중에도 시작·종료되므로 오래 살려 두면 안 된다.
///
/// 진행 중 세션을 **먼저** 찾는다. 서버가 최신순으로 주므로 대개 첫 항목이 곧
/// 진행 중 세션이지만, 정렬을 믿고 고르면 이력 순서가 바뀌었을 때 "운행 중"인
/// 버스를 관리자가 "운행 종료"로 읽는다. 그 오독은 조치를 바꾼다.
final adminBusSessionProvider = FutureProvider.autoDispose
    .family<DriveSession?, AdminBusSessionQuery>((ref, query) async {
      final sessions = await ref
          .read(adminDriveSessionRepositoryProvider)
          .tenantSessions(tenantId: query.tenantId);

      DriveSession? latest;
      for (final session in sessions) {
        if (session.busId != query.busId) continue;
        if (session.isInProgress) return session;
        if (latest == null || latest.startedAt.isBefore(session.startedAt)) {
          latest = session;
        }
      }
      return latest;
    });
