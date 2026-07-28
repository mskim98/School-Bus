import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../domain/route_plan.dart';

/// 정차 순서 목록의 한 장(`docs/DESIGN_SYSTEM.md` §5.2).
///
/// 세 상태를 **한 장에서만** 구분한다 — 다음 정차 / 예정 / 완료. 목록에서 진하게
/// 튀는 카드가 하나뿐이어야 운전 중 1초 안에 "다음에 갈 곳"이 읽힌다.
///
/// ⚠️ **학생 이름을 아직 못 보여준다.** 노선 API(`stops[]`)는 `studentId` 만 주고
/// 이름은 운행 세션 명단에서만 온다(계획서 §3.11). C7 에서 운행 세션을 붙이면
/// 이 자리에 이름이 들어간다 — 그때까지는 정차 순번을 앞세워 순서만 읽히게 한다.
class RouteStopTile extends StatelessWidget {
  const RouteStopTile({
    super.key,
    required this.stop,
    this.isNext = false,
    this.isLast = false,
    this.isDone = false,
    this.studentName,
  });

  final RouteStop stop;

  /// 다음에 가야 할 정차 — 운전 중 한눈에 들어와야 한다.
  final bool isNext;

  final bool isLast;

  /// 이미 지나온 정차. 지우지 않고 흐리게 남긴다 — 순서를 되짚을 수 있어야 한다.
  final bool isDone;

  /// C7 에서 운행 세션 명단이 붙으면 채워진다.
  final String? studentName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // 다음 정차만 primaryContainer 로 올린다. 나머지는 카드 표면색으로 눕힌다.
    final tone = isNext ? AppTone.primary : AppTone.neutral;
    final background = isNext
        ? scheme.primaryContainer
        : scheme.surfaceContainer;
    final foreground = isNext ? scheme.onPrimaryContainer : scheme.onSurface;
    final subForeground = isNext
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          // 순번 원형 — 지도 마커의 숫자와 같은 값이라 서로 대응시켜 볼 수 있다.
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isNext ? tone.solid(context) : tone.container(context),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${stop.seq}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: isNext
                    ? tone.onSolid(context)
                    : tone.onContainer(context),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.smd),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName ?? '학생 #${stop.studentId}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // 글자 200% 확대에서도 태그가 밀려나지 않게 Wrap 을 쓴다(§7-5).
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppTag(label: _stateLabel, tone: tone, filled: isNext),
                    if (isLast && !isDone)
                      const AppTag(label: '마지막 정차', tone: AppTone.neutral),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.smd),

          // ETA 는 서버가 초로 주므로 사람이 읽는 형태로 바꿔 보여준다(§7-8).
          // 변환은 도메인(`RouteStop.etaLabel`)에 있다 — 화면마다 다시 만들지 않는다.
          Text(
            isDone ? '—' : stop.etaLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: isNext ? foreground : subForeground,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return isDone ? Opacity(opacity: 0.6, child: card) : card;
  }

  /// 태그 문구는 세 가지뿐이다(시안 `stopList.tag`). 화면에서 새로 짓지 않는다.
  String get _stateLabel {
    if (isDone) return '완료';
    return isNext ? '다음 정차' : '예정';
  }
}
