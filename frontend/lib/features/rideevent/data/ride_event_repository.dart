import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_response.dart';
import '../domain/ride_event.dart';
import 'dto/ride_event_dto.dart';

/// 승하차 기록.
///
/// 서버가 하나뿐이고 교체 계획이 없어 포트로 나누지 않는다(컨벤션 §5).
class RideEventRepository {
  const RideEventRepository(this._client);

  final ApiClient _client;

  /// 승차/하차/인계 기록.
  ///
  /// ⚠️ **기록 즉시 학부모에게 알림이 나가고 되돌릴 수 없다.** 호출부는 응답을
  /// 받기 전에 화면 상태를 미리 바꾸지 않는다(계획서 §5.4).
  ///
  /// [stopId]·[lat]·[lng] 는 선택이다 — 생략하면 서버가 학생의 기본 정류장으로
  /// 채운다. `source` 는 서버가 `MANUAL` 로 채우므로 보내지 않는다.
  Future<RideEvent> record({
    required int busId,
    required int studentId,
    required RideEventType type,
    int? stopId,
    double? lat,
    double? lng,
  }) async {
    final dto = await _client.post(
      '/api/ride-events',
      body: {
        'busId': busId,
        'studentId': studentId,
        'type': type.wireName,
        // 값이 null 이면 키 자체를 빼서 서버 기본값(학생의 기본 정류장)을 쓰게 한다.
        'stopId': ?stopId,
        'lat': ?lat,
        'lng': ?lng,
      },
      decode: Decode.one(RideEventDto.fromJson),
    );
    final event = RideEvent.fromDto(dto);
    if (event == null) {
      // 우리가 보낸 종류를 서버가 해석 불가능한 값으로 되돌려준 상황.
      // 조용히 넘기면 화면이 틀린 단계를 보여주게 되므로 실패로 다룬다.
      throw const FormatException('알 수 없는 승하차 종류가 응답에 담겼습니다');
    }
    return event;
  }

  /// 버스의 그날 승하차 이력. **날짜 단위**라 그날 여러 운행의 기록이 함께 온다.
  /// 운행 단위로 걸러 쓰는 건 `RosterStudent.merge` 의 몫이다.
  ///
  /// 빈 배열은 정상이다 — 아직 아무도 안 탔다는 뜻이다(컨벤션 §7-4).
  Future<List<RideEvent>> busRecords({
    required int busId,
    required DateTime date,
  }) async {
    final dtos = await _client.get(
      '/api/ride-events/bus/$busId',
      query: {'date': _formatDate(date)},
      decode: Decode.list(RideEventDto.fromJson),
    );
    // 해석 못 하는 종류의 기록은 버린다 — 그 한 건 때문에 명단 전체가 죽지 않게.
    return [for (final dto in dtos) ?RideEvent.fromDto(dto)];
  }

  /// 서버가 요구하는 `yyyy-MM-dd`.
  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

final rideEventRepositoryProvider = Provider<RideEventRepository>(
  (ref) => RideEventRepository(ref.watch(apiClientProvider)),
);
