import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ⚠️ feature 간 의존이 하나 있다(컨벤션 C-1).
// 부제의 날짜는 **운행 세션의 `serviceDate`** 여야 한다 — 기기 시계(`DateTime.now()`)
// 를 쓰면 자정을 넘겨 운행하는 하원 편이 하루 뒤 날짜로 표시된다. 그 값은
// drivesession 에만 있다. 원칙대로면 `shared/domain/` 으로 올려야 하지만
// 이미 rideevent → drivesession 방향으로 같은 예외가 있어(`driver_roster_controller.dart`)
// 방향을 늘리지 않는 선에서 bus → drivesession 한쪽으로만 고정해 둔다.
import '../../../drivesession/application/drive_session_controller.dart';
import '../../application/my_bus_controller.dart';

/// 기사 앱바 제목 아래 한 줄 — `3호차 · 하원 A노선 · 2026. 7. 28.`.
///
/// 기사는 이 앱을 하루 종일 켜 두고, 학원에 따라 차와 노선이 편마다 바뀐다.
/// "지금 내가 어느 차로 어느 편을 몰고 있는가"를 화면을 옮겨 다녀도 항상 보이게
/// 앱바에 붙인다.
///
/// **값이 없으면 아무것도 그리지 않는다.** `불러오는 중…` 같은 자리표시자를 두면
/// 앱바가 매번 두 줄로 커졌다 줄었다 해서 제목이 흔들리고, 무엇보다 기사가
/// 남의 차 이름을 잠깐이라도 보게 될 여지를 만들지 않는다.
class DriverAppBarSubtitle extends ConsumerWidget {
  const DriverAppBarSubtitle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bus = ref.watch(myBusControllerProvider).value;
    if (bus == null) return const SizedBox.shrink();

    // 운행 전에는 세션이 없다 — 그때는 날짜 없이 `3호차 · 하원 A노선` 까지만.
    final session = ref.watch(activeDriveSessionProvider);
    final parts = [
      ...bus.titleParts,
      if (session != null) _formatDate(session.serviceDate),
    ];

    // 좁은 폰에서 노선명이 길면 제목까지 밀려나므로 한 줄로 자른다.
    return Text(
      parts.join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 시안 표기(`2026. 7. 28.`). `intl` 을 들이지 않으려고 직접 조립한다 —
  /// 앱 전체에서 날짜를 사람이 읽게 쓰는 자리가 지금 여기 하나뿐이다.
  static String _formatDate(DateTime date) =>
      '${date.year}. ${date.month}. ${date.day}.';
}
