import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../domain/drive_session.dart';
import 'dto/drive_session_dto.dart';

/// 운행 세션(운행 시작·명단·운행 종료).
///
/// 서버가 하나뿐이고 교체 계획이 없어 포트로 나누지 않는다(컨벤션 §5).
class DriveSessionRepository {
  const DriveSessionRepository(this._client);

  final ApiClient _client;

  /// 운행 시작. 같은 버스에 진행 중인 운행이 이미 있으면 **409** 가 온다
  /// (message: "이미 진행 중인 운행이 있습니다").
  Future<DriveSession> start({
    required int busId,
    required DriveDirection direction,
  }) async {
    final dto = await _client.post(
      '/api/drive-sessions/start',
      body: {'busId': busId, 'direction': direction.wireName},
      decode: Decode.one(DriveSessionDto.fromJson),
    );
    return DriveSession.fromDto(dto);
  }

  /// 지금 진행 중인 운행. 없으면 null.
  ///
  /// 서버에 "현재 세션" 전용 엔드포인트가 없어서 이력을 받아 `IN_PROGRESS` 를 고른다.
  /// 이력은 **최신순**으로 오므로 첫 번째 진행 중 항목이 곧 현재 운행이다.
  /// 앱을 껐다 켜도 운행이 이어지려면 이 조회가 필요하다.
  Future<DriveSession?> findActive(int busId) async {
    final dtos = await _client.get(
      '/api/drive-sessions/bus/$busId',
      decode: Decode.list(DriveSessionDto.fromJson),
    );
    for (final dto in dtos) {
      final session = DriveSession.fromDto(dto);
      if (session.isInProgress) return session;
    }
    return null;
  }

  /// 운행 명단. 결석 신고된 학생은 서버가 이미 제외한 상태로 온다.
  Future<List<RosterEntry>> roster(int sessionId) async {
    final dtos = await _client.get(
      '/api/drive-sessions/$sessionId/roster',
      decode: Decode.list(DriveSessionRosterEntryDto.fromJson),
    );
    return dtos.map(RosterEntry.fromDto).toList(growable: false);
  }

  /// 운행 종료. **차내에 하차하지 않은 학생이 남아 있으면 409 로 거절된다**
  /// (message: "하차 처리되지 않은 학생이 있어 운행을 종료할 수 없습니다").
  /// 아이를 차에 두고 가는 사고를 막는 서버 측 안전장치라, 클라이언트가 우회하지 않는다.
  Future<DriveSession> end(int sessionId) async {
    final dto = await _client.patch(
      '/api/drive-sessions/$sessionId/end',
      decode: Decode.one(DriveSessionDto.fromJson),
    );
    return DriveSession.fromDto(dto);
  }
}

final driveSessionRepositoryProvider = Provider<DriveSessionRepository>(
  (ref) => DriveSessionRepository(ref.watch(apiClientProvider)),
);
