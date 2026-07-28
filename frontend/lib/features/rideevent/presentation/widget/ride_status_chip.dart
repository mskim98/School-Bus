import 'package:flutter/material.dart';

import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../domain/ride_event.dart';
import '../../domain/roster_student.dart';

/// 승하차 상태 표기 — **상태 계약(`docs/DESIGN_SYSTEM.md` §4)을 코드로 옮긴 유일한 지점**.
///
/// 같은 상태를 기사 앱과 관리자 웹이 다르게 그리면 그 자체가 사고다. 그래서
/// 아이콘·톤 매핑을 여기 한 곳에만 두고, 화면에서는 칩을 새로 만들지 않는다(§7-3).
///
/// 라벨은 [RideStatus.label] 을 그대로 쓴다. 문자열을 여기서 다시 적으면
/// 도메인과 두 벌이 되어 언젠가 갈라지는데, 그 enum 값이 이미 §4 표의 문자열
/// (`대기` · `승차 완료` · `하차 완료` · `보호자 인계 완료`)이다.
class RideStatusChip extends StatelessWidget {
  const RideStatusChip({super.key, required this.status});

  final RideStatus status;

  @override
  Widget build(BuildContext context) {
    return AppStatusChip(
      icon: iconOf(status),
      label: status.label,
      tone: toneOf(status),
    );
  }

  /// 하차를 `warning`, 인계를 `success` 로 나눈 건 의도다.
  ///
  /// 버스에서 내린 것과 보호자에게 넘긴 것은 **책임이 갈리는 지점**이라 서버도
  /// 따로 받는다([RideEventType]). 색까지 같으면 기사가 "내려줬다"와 "넘겼다"를
  /// 구분하지 않게 되고, 그 순간 학부모에게 나가는 알림이 어긋난다.
  static AppTone toneOf(RideStatus status) => switch (status) {
    RideStatus.waiting => AppTone.neutral,
    RideStatus.boarded => AppTone.primary,
    RideStatus.alighted => AppTone.warning,
    RideStatus.handedOver => AppTone.success,
  };

  /// §4 표의 아이콘 문자. 직사광선 아래서 색이 안 읽혀도 이건 읽힌다.
  static String iconOf(RideStatus status) => switch (status) {
    RideStatus.waiting => '·',
    RideStatus.boarded => '↑',
    RideStatus.alighted => '↓',
    RideStatus.handedOver => '✓',
  };
}

/// 다음에 눌러야 할 동작의 표기 — 아이콘·톤을 [RideStatusChip] 과 같은 파일에 둔다.
///
/// 상태 칩(`↓ 하차 완료`)과 그 상태로 가는 버튼(`↓ 하차`)이 다른 색이면 기사가
/// 둘을 다른 개념으로 읽는다. 매핑을 떨어뜨려 두면 반드시 어긋나므로 붙여 둔다.
extension RideActionStyle on RideEventType {
  AppTone get tone => switch (this) {
    RideEventType.board => AppTone.primary,
    RideEventType.alight => AppTone.warning,
    RideEventType.handover => AppTone.success,
  };

  String get icon => switch (this) {
    RideEventType.board => '↑',
    RideEventType.alight => '↓',
    RideEventType.handover => '✓',
  };
}

/// 미승차 배지 — 도착 10분 뒤 서버가 발행하는 부가 상태(§4 표 마지막 줄).
///
/// 상태 칩이 아니라 **태그**인 이유: 미승차여도 학생의 단계는 여전히 `대기`다.
/// 칩을 `미승차` 로 바꿔치우면 "이 학생은 아직 태울 수 있다"는 사실이 사라진다.
class NoShowBadge extends StatelessWidget {
  const NoShowBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppTag(label: '! 미승차', tone: AppTone.error);
  }
}
