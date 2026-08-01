import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../domain/route_stop_group.dart';

/// 정차 순서 목록의 한 장 — **학생이 아니라 정차 한 곳**을 그린다
/// (`docs/DESIGN_SYSTEM.md` §5.2, 시안 `기사앱 MVP.dc.html` 349~364줄).
///
/// 서버 `stops[]` 는 학생 단위라 그대로 그리면 같은 정류장이 인원수만큼 반복된다.
/// 묶는 일은 [RouteStopGroup] 이 하고 이 위젯은 결과를 받아 그리기만 한다 —
/// 제목·보조줄·ETA 문구를 화면에서 다시 만들지 않는다(§7-8).
///
/// 세 상태를 **한 장에서만** 구분한다 — 다음 정차 / 예정 / 완료. 목록에서 진하게
/// 튀는 카드가 하나뿐이어야 운전 중 1초 안에 "다음에 갈 곳"이 읽힌다.
class RouteStopGroupTile extends StatelessWidget {
  const RouteStopGroupTile({
    super.key,
    required this.group,
    this.isNext = false,
    this.isLast = false,
    this.isDone = false,
    this.progressLabel,
  });

  /// 이 폭을 넘어가면 제목·ETA 가 한 줄에 안 들어간다. 그때는 세로로 접는다 —
  /// 잘린 카드보다 두 줄짜리 카드가 낫다(§7-5). 같은 화면의
  /// `RosterStudentTile` · `_RouteSummary` 와 같은 기준값이다.
  static const double _stackAboveTextScale = 1.15;

  /// 순번 배지 지름(글자 배율 100% 기준). 지도 마커(§5.3)·명단 그룹 카드와 같은 32 다.
  static const double _badgeSize = 32;

  final RouteStopGroup group;

  /// 다음에 가야 할 정차 — 운전 중 한눈에 들어와야 한다.
  final bool isNext;

  final bool isLast;

  /// 이 정차의 학생을 전부 처리했다. 지우지 않고 흐리게 남긴다 —
  /// 순서를 되짚을 수 있어야 한다.
  final bool isDone;

  /// 우하단 진행률(`0/2명`). 운행 전에는 명단이 없어 셀 수 없으므로,
  /// 넘기지 않으면 인원수(`2명`)만 낸다 — 0 으로 채우면 시작도 안 한 운행이
  /// "아무도 안 탔다"로 읽힌다.
  final String? progressLabel;

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

    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > _stackAboveTextScale;

    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _badge(context, tone),
                    const SizedBox(width: AppSpacing.smd),
                    Expanded(child: _body(theme, foreground, subForeground)),
                  ],
                ),
                const SizedBox(height: AppSpacing.smd),
                _trailing(theme, foreground, subForeground, alignEnd: false),
              ],
            )
          : Row(
              children: [
                _badge(context, tone),
                const SizedBox(width: AppSpacing.smd),
                Expanded(child: _body(theme, foreground, subForeground)),
                const SizedBox(width: AppSpacing.smd),
                _trailing(theme, foreground, subForeground, alignEnd: true),
              ],
            ),
    );

    return isDone ? Opacity(opacity: 0.6, child: card) : card;
  }

  /// 순번 배지 — 지도 마커의 숫자와 같은 값이라 서로 대응시켜 볼 수 있다.
  Widget _badge(BuildContext context, AppTone tone) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return Container(
      // 글자를 키우면 배지도 같이 키운다 — 지름을 32 로 고정하면 두 자리 순번이
      // 200% 확대에서 원 밖으로 밀린다. 명단의 `RosterStopGroupCard` 헤더 배지와
      // **같은 계산**이다. 두 화면의 같은 배지가 다른 규칙을 쓰면 안 된다.
      width: _badgeSize * scale,
      height: _badgeSize * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isNext ? tone.solid(context) : tone.container(context),
        shape: BoxShape.circle,
      ),
      child: Text(
        '${group.seq}',
        style: theme.textTheme.labelLarge?.copyWith(
          color: isNext ? tone.onSolid(context) : tone.onContainer(context),
          // 숫자 폭이 흔들리지 않게 자릿수를 고정한다(§2.2 Mono 대체).
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  /// 제목 · 상태 태그 · 보조 줄.
  Widget _body(ThemeData theme, Color foreground, Color subForeground) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 글자 200% 확대에서도 태그가 밀려나지 않게 Wrap 을 쓴다(§7-5).
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              group.title,
              style: theme.textTheme.titleMedium?.copyWith(color: foreground),
            ),
            AppTag(
              label: _stateLabel,
              tone: isNext ? AppTone.primary : AppTone.neutral,
              filled: isNext,
            ),
            if (isLast && !isDone)
              const AppTag(label: '마지막 정차', tone: AppTone.neutral),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // 운행 전에는 인원수(`2명`), 운행 중에는 학생 이름이 온다.
        // 어느 쪽인지는 도메인이 정한다(`RouteStopGroup.subtitle`).
        Text(
          group.subtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: subForeground),
        ),
      ],
    );
  }

  /// ETA + 진행률.
  Widget _trailing(
    ThemeData theme,
    Color foreground,
    Color subForeground, {
    required bool alignEnd,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ETA 는 서버가 초로 주므로 사람이 읽는 형태로 바꿔 보여준다(§7-8).
        // 변환은 도메인(`RouteStopGroup.etaLabel`)에 있다.
        Text(
          isDone ? '—' : group.etaLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            color: isNext ? foreground : subForeground,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          progressLabel ?? '${group.studentCount}명',
          style: theme.textTheme.bodySmall?.copyWith(
            color: subForeground,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  /// 태그 문구는 세 가지뿐이다(시안 `stopList.tag`). 화면에서 새로 짓지 않는다.
  String get _stateLabel {
    if (isDone) return '완료';
    return isNext ? '다음 정차' : '예정';
  }
}
