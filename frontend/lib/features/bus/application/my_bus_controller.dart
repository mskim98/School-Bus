import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/domain/role.dart';
import '../../auth/application/auth_controller.dart';
import '../data/bus_repository.dart';
import '../domain/my_bus.dart';

/// 기사의 담당 버스. **기사 화면 여러 곳이 공유한다**(앱바 부제·운행 시작 카드).
///
/// 화면마다 `GET /api/buses/me` 를 부르지 않고 여기서 한 번 받아 캐시한다.
/// 앱바와 카드가 따로 부르면 같은 화면 하나를 그리는 데 요청이 두 번 나가고,
/// 응답 시점이 어긋나 호차명이 두 자리에서 다른 순간에 나타난다.
///
/// 값이 null 인 경우가 둘이라 화면은 이를 구분하지 않아도 되게 만들어 뒀다 —
/// 기사가 아니거나(부를 이유가 없음), 아직 배차되지 않았거나(404). 어느 쪽이든
/// "보여줄 버스가 없다"가 화면이 할 일의 전부다.
class MyBusController extends AsyncNotifier<MyBus?> {
  @override
  Future<MyBus?> build() async {
    // 로그인·로그아웃으로 세션이 바뀌면 자동으로 다시 부른다.
    final session = ref.watch(currentSessionProvider);
    // 기사 전용 API 다. 관리자로 부르면 403 이 오는데, 그건 다룰 오류가 아니라
    // 애초에 보낼 이유가 없는 요청이다.
    if (session == null || session.role != Role.driver) return null;

    return ref.read(busRepositoryProvider).findMyBus();
  }

  /// 서버 사실을 다시 읽는다. 배차가 방금 바뀐 경우의 복구용이다.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final myBusControllerProvider = AsyncNotifierProvider<MyBusController, MyBus?>(
  MyBusController.new,
);
