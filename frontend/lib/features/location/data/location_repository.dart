import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../domain/monitored_bus.dart';
import 'dto/bus_location_dto.dart';
import 'dto/bus_summary_dto.dart';

/// 버스 위치 보고(기사) · 조회(관리자).
///
/// 서버가 하나뿐이고 교체 계획이 없어 포트로 나누지 않는다(컨벤션 §5).
class LocationRepository {
  const LocationRepository(this._client);

  final ApiClient _client;

  /// 기사가 자기 버스의 현재 좌표를 보고한다(`POST /api/locations/bus`, 권한 `DRIVER`).
  ///
  /// [origin] 은 그 좌표를 만든 소스다 — 서버가 그대로 기록해 관제 화면의 "출처"
  /// 표기가 된다. 문자열 변환은 [LocationOrigin.wireName] 한 곳에서만 한다.
  /// 필드를 빼고 보내면 서버가 `GPS` 로 처리하므로 구버전 서버와도 어긋나지 않는다.
  ///
  /// 응답 본문이 없다(`data: null`). 담당 버스가 아니면 403 이 온다.
  Future<void> reportBusLocation({
    required int busId,
    required double lat,
    required double lng,
    required LocationOrigin origin,
  }) {
    return _client.post(
      '/api/locations/bus',
      body: {
        'busId': busId,
        'lat': lat,
        'lng': lng,
        'origin': origin.wireName,
      },
      decode: Decode.unit,
    );
  }

  /// 학원의 버스 최신 위치(`GET /api/locations/buses`).
  ///
  /// [tenantId] 는 `ACADEMY_ADMIN` 이면 생략 가능(서버가 본인 학원으로 채운다),
  /// **`PLATFORM_ADMIN` 은 필수**다 — 빼면 400 이다(실측 확인).
  ///
  /// ⚠️ 보고 이력이 없는 버스는 **결과에 아예 없다**. 목록이 짧다고 에러가 아니다.
  Future<List<BusLocationDto>> getBusLocations({int? tenantId}) {
    return _client.get(
      '/api/locations/buses',
      query: {'tenantId': tenantId},
      decode: Decode.list(BusLocationDto.fromJson),
    );
  }

  /// 학원의 버스 목록(`GET /api/buses`).
  ///
  /// 위치가 없는 버스까지 관제 화면에 세우려고 함께 부른다(계획서 §3.6).
  /// [tenantId] 규칙은 [getBusLocations] 와 같다.
  Future<List<BusSummaryDto>> getBuses({int? tenantId}) {
    return _client.get(
      '/api/buses',
      query: {'tenantId': tenantId},
      decode: Decode.list(BusSummaryDto.fromJson),
    );
  }
}

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepository(ref.watch(apiClientProvider)),
);
