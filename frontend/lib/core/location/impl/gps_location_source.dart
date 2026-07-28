import 'package:geolocator/geolocator.dart';

import '../../map/spec/map_view_adapter.dart';
import '../spec/location_source.dart';

/// 단말의 실제 GPS 를 읽는 [LocationSource].
///
/// **이 파일이 `geolocator` 를 아는 유일한 곳이다.** 화면·상태 계층은 [LocationSource]
/// 만 보므로 위치 라이브러리를 바꿔도 여기만 갈아끼우면 된다(컨벤션 §5, 검사 C-1).
class GpsLocationSource implements LocationSource {
  const GpsLocationSource();

  /// 좌표 한 개를 기다리는 최대 시간. 전송 주기(5초)보다 짧게 잡아
  /// 요청이 겹쳐 쌓이지 않게 한다.
  static const _timeout = Duration(seconds: 4);

  @override
  Future<GeoPoint> read() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailableException(
        '단말의 위치 서비스가 꺼져 있습니다. 설정에서 켠 뒤 다시 시도해 주세요',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 아직 물어본 적이 없는 상태 — 여기서 한 번 요청한다.
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationUnavailableException(
        '위치 권한이 거부되었습니다. 권한을 허용하거나 Mock 으로 전환해 주세요',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      // 다시 물어봐도 시스템이 대화상자를 띄우지 않는다 → 설정 앱으로 안내한다.
      throw const LocationUnavailableException(
        '위치 권한이 영구 거부되어 있습니다. 시스템 설정에서 직접 허용해 주세요',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: _timeout,
      ),
    );
    return GeoPoint(position.latitude, position.longitude);
  }
}
