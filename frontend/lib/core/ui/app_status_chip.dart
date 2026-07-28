import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import 'app_tone.dart';

/// 상태 표기 칩 — **아이콘 + 라벨을 항상 같이** 낸다.
///
/// 이 앱은 직사광선 아래 운전석에서 쓰이고, 색각 이상 사용자도 있다.
/// 그래서 상태를 **색만으로 구분하지 않는다**(`docs/DESIGN_SYSTEM.md` §0-1).
/// [icon] 과 [label] 을 둘 다 필수로 받는 게 그 규칙을 코드로 강제하는 방법이다.
///
/// **읽기 전용이다.** 탭 동작을 붙이지 않는다(§5.1) — 상태 표기가 눌리면
/// 사용자는 그걸로 상태를 바꿀 수 있다고 오해한다. 상태 변경은 액션 버튼이 한다.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.icon,
    required this.label,
    required this.tone,
  });

  /// 텍스트 아이콘(`·` `↑` `↓` `✓` `!`). 상태 계약(§4)이 정한 문자를 그대로 쓴다.
  final String icon;
  final String label;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: tone.onContainer(context));

    return Container(
      // 시안은 10×5 지만 4dp 스케일에 맞춰 12×4 로 둔다(§3.1).
      // 육안 차이가 없고, 여기서 스케일을 깨면 아래 위젯들이 따라 깨진다.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tone.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text('$icon $label', style: style),
    );
  }
}

/// 작은 태그(`다음 정차` · `예정` · `NEW` 등).
///
/// [AppStatusChip] 과 나눈 이유는 의미가 다르기 때문이다 — 칩은 **대상의 상태**,
/// 태그는 **목록 안에서의 위치·분류**다. 크기도 한 단 작다(§2.1 labelSmall).
class AppTag extends StatelessWidget {
  const AppTag({
    super.key,
    required this.label,
    required this.tone,
    this.filled = false,
  });

  final String label;
  final AppTone tone;

  /// `true` 면 진한 [AppTone.solid] 바탕 — "다음 정차"처럼 하나만 튀어야 할 때.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = filled ? tone.solid(context) : tone.container(context);
    final foreground = filled
        ? tone.onSolid(context)
        : tone.onContainer(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
