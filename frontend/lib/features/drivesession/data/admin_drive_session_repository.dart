import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../domain/drive_session.dart';
import 'dto/drive_session_dto.dart';

/// 관리자용 운행 세션 조회.
///
/// [DriveSessionRepository](drive_session_repository.dart) 와 **일부러 나눠 둔다.**
/// 그쪽은 전부 `hasRole('DRIVER')` 라 관리자가 부르면 403 이다 — 특히
/// `GET /api/drive-sessions/bus/{busId}` 는 이름만 보면 관제에 딱 맞아 보이지만
/// 기사 전용이고, 게다가 "그 버스에 배차된 기사인지"까지 서버가 검사한다.
/// 관리자에게 열려 있는 건 학원 단위 이력 하나뿐이다.
class AdminDriveSessionRepository {
  const AdminDriveSessionRepository(this._client);

  final ApiClient _client;

  /// 학원의 운행 이력(`GET /api/drive-sessions`, 권한 `ACADEMY_ADMIN`·`PLATFORM_ADMIN`).
  ///
  /// **최신순**(`startedAt` 내림차순)으로 오고 버스·날짜 필터가 없다 — 학원 전체가
  /// 통째로 온다. 버스 하나만 보려면 클라이언트가 골라야 한다.
  ///
  /// [tenantId] 는 `ACADEMY_ADMIN` 이면 생략 가능(서버가 본인 학원으로 채운다),
  /// `PLATFORM_ADMIN` 은 사실상 필수다.
  ///
  /// 빈 배열은 정상이다 — 아직 아무도 운행을 시작하지 않았다는 뜻이다(컨벤션 §7-4).
  Future<List<DriveSession>> tenantSessions({int? tenantId}) async {
    final dtos = await _client.get(
      '/api/drive-sessions',
      query: {'tenantId': tenantId},
      decode: Decode.list(DriveSessionDto.fromJson),
    );
    return dtos.map(DriveSession.fromDto).toList(growable: false);
  }
}

final adminDriveSessionRepositoryProvider = Provider<AdminDriveSessionRepository>(
  (ref) => AdminDriveSessionRepository(ref.watch(apiClientProvider)),
);
