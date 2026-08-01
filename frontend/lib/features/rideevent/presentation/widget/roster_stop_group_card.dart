import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../domain/roster_stop_group.dart';
import '../../domain/roster_student.dart';

/// 정차 한 곳을 접었다 펴는 카드(시안 `기사앱 MVP.dc.html` 406~469줄).
///
/// 학생 행을 평평하게 나열하면 3명일 때는 읽히지만 정원 25명에서는 "이번 정류장에서
/// 누구를 태우는가"가 목록 어디에도 안 나온다. 그래서 정차 단위로 묶고, **처리가
/// 끝난 정차는 접어** 남은 일만 화면에 남긴다.
///
/// 규칙 셋:
///  1. 헤더 문구·진행률·접힘 요약을 **여기서 만들지 않는다** — 전부 [RosterStopGroup]
///     이 갖고 있다. 두 곳에서 지으면 그룹 진행률과 학생 행의 완료 표시가 어긋난다
///  2. 펼친 본문은 [rowBuilder] 가 넘겨주는 학생 행을 그대로 쓴다. 상태 칩·액션 버튼
///     규칙(§4)은 `RosterStudentTile` 한 곳에만 있다
///  3. 완료된 그룹은 **색만 다르게 하지 않는다**(§0-1) — 체크 아이콘과 `n/n명` 을
///     같이 낸다. 직사광선 아래 운전석에서 톤 차이는 잘 안 보인다
class RosterStopGroupCard extends StatelessWidget {
  const RosterStopGroupCard({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.rowBuilder,
  });

  final RosterStopGroup group;

  /// 펼침 여부. 판단(기본값 규칙 + 사용자 조작)은 화면이 한다 — 카드는 결과만 그린다.
  final bool expanded;

  final VoidCallback onToggle;

  /// 펼쳤을 때 그릴 학생 행. 화면이 `RosterStudentTile` 을 만들어 넘긴다.
  final Widget Function(BuildContext context, RosterStudent student) rowBuilder;

  /// 순번 배지 지름. 지도 마커(§5.3)·노선 카드와 같은 32 다.
  static const double _badgeSize = 32;

  /// 이 배율을 넘으면 헤더를 세로로 접는다 — 진행률과 화살표가 제목을 밀어내면
  /// 정류장 이름이 잘린다(§7-5). `RosterStudentTile` 과 같은 기준을 쓴다.
  static const double _stackAboveTextScale = 1.15;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // 목록 위에 단독으로 놓이는 카드라 20 이다(§3.2). 안에 들어가는 학생 행은
        // 12 라 위계가 구분된다.
        //
        // ⚠️ 카드 자체는 `surface`(= 화면 배경)다. `surfaceContainer` 를 쓰면
        // 안에 들어가는 `RosterStudentTile` 도 `surfaceContainer` 라 **펼친 행이
        // 카드에 잠겨 버린다**. 여기서는 테두리로만 구획하고(§3.4 "카드는 그림자
        // 대신 1px 테두리"), 실제로 눌러야 할 학생 행이 한 단 떠 보이게 둔다.
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            group: group,
            expanded: expanded,
            onToggle: onToggle,
            badgeSize: _badgeSize,
            stackAboveTextScale: _stackAboveTextScale,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.smd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, student) in group.students.indexed) ...[
                    // 오탭 방지 — 행마다 액션 버튼이 하나씩 있다(§3.3).
                    if (index > 0) const SizedBox(height: AppSpacing.smd),
                    rowBuilder(context, student),
                  ],
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.smd,
              ),
              child: Text(
                group.collapsedSummary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 카드 헤더 — **카드 전폭을 차지하는 버튼 하나**다.
///
/// 접기/펴기를 작은 화살표에만 걸면 흔들리는 차 안에서 조준이 안 된다. 헤더 전체가
/// 56dp 짜리 타깃이라 어디를 눌러도 열린다(§3.3).
class _Header extends StatelessWidget {
  const _Header({
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.badgeSize,
    required this.stackAboveTextScale,
  });

  final RosterStopGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final double badgeSize;
  final double stackAboveTextScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final tone = group.isDone ? AppTone.neutral : AppTone.primary;

    final badge = Container(
      // 글자를 키우면 배지도 같이 키운다 — 지름을 32 로 고정하면 두 자리 순번이
      // 200% 확대에서 원 밖으로 밀린다.
      width: badgeSize * scale,
      height: badgeSize * scale,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.container(context),
        shape: BoxShape.circle,
      ),
      child: Text(
        '${group.seq}',
        style: theme.textTheme.labelLarge?.copyWith(
          color: tone.onContainer(context),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

    final titles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 제목과 태그를 Row 로 두면 긴 하차 주소가 태그를 화면 밖으로 민다(§7-5).
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(group.title, style: theme.textTheme.titleMedium),
            AppTag(label: group.kindLabel, tone: tone),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          group.countLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final progress = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      children: [
        if (group.isDone)
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        Text(
          group.progressLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );

    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onToggle,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppTouch.primary),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: scale > stackAboveTextScale
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          badge,
                          const SizedBox(width: AppSpacing.smd),
                          Expanded(child: titles),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      progress,
                    ],
                  )
                : Row(
                    children: [
                      badge,
                      const SizedBox(width: AppSpacing.smd),
                      Expanded(child: titles),
                      const SizedBox(width: AppSpacing.smd),
                      progress,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
