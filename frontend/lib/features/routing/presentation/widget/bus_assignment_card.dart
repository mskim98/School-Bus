import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../domain/route_plan.dart';
import '../../domain/route_plan_status.dart';
import '../../domain/route_stop_group.dart';
import 'route_plan_card.dart';

/// 버스 한 대에 **무엇이 배정됐는지** — 확정 버튼을 누르기 전에 봐야 할 근거.
///
/// [RoutePlanCard] 는 `버스 #1 · 정차 4곳 · 3.5km` 까지만 낸다. 그걸로는
/// "이 버스에 누가 타는지" 도 "자리가 남는지" 도 알 수 없어서, 관리자가 확정을
/// 되돌릴 수 없는 동작에 서명하는 셈이 된다. 그래서 목록 카드와 나눠 뒀다 —
/// 노선 목록은 훑는 화면이고 여기는 **판단하는 화면**이다.
///
/// 규칙 셋:
///  1. **명단은 정차 단위로 묶는다**(§5.4). 서버 `stops[]` 는 학생 한 명당 한 줄이라
///     그대로 나열하면 같은 정류장이 인원수만큼 반복된다. 묶는 일은
///     [RouteStopGroup.group] 이 하고 여기는 결과만 그린다 — 기사 앱과 같은 규칙이다
///  2. **모르는 값을 지어내지 않는다.** 호차명·학생 이름·좌석 수는 별도 명부에서
///     오고, 아직 안 왔으면 `버스 #1`·`#7` 로 뜨고 정원 칸은 비운다. 명부가
///     안 왔다고 제안 결과가 가려지면 안 된다
///  3. **정원 상태를 색만으로 구분하지 않는다**(§0-1) — 진행바 색과 함께 아이콘·
///     한글 라벨을 항상 낸다
class BusAssignmentCard extends StatefulWidget {
  const BusAssignmentCard({
    super.key,
    required this.plan,
    this.busName,
    this.seatCapacity,
    this.studentNameOf,
  });

  /// 배정 인원이 이 수를 넘으면 학생 명단을 **접고 시작한다.**
  ///
  /// 정원은 25석까지 간다(§9). 전부 펼쳐 두면 버스 3대만 돼도 카드 하나가
  /// 화면을 다 먹어 버스 간 비교가 스크롤 밖으로 밀린다.
  static const int collapseAbove = 8;

  final RoutePlan plan;

  /// 호차명(`3호차`). null 이면 `버스 #id` — 명부를 못 받아도 카드는 뜬다.
  final String? busName;

  /// 좌석 수. **null 이면 정원 칸을 비운다** — 0 으로 채우면 "정원 초과"로 읽힌다.
  final int? seatCapacity;

  /// `studentId → 이름`. null 이면 `#id` 로 남긴다(누군지 아직 모른다는 표기다).
  final String Function(int studentId)? studentNameOf;

  @override
  State<BusAssignmentCard> createState() => _BusAssignmentCardState();
}

class _BusAssignmentCardState extends State<BusAssignmentCard> {
  /// 사용자가 직접 접거나 편 결과. null 이면 인원수로 정한 기본값을 쓴다.
  bool? _expandedOverride;

  bool get _expanded =>
      _expandedOverride ??
      widget.plan.stops.length <= BusAssignmentCard.collapseAbove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plan = widget.plan;

    // 정차 수는 **묶은 뒤**의 값이다. `stops.length` 를 쓰면 같은 정류장이
    // 인원수만큼 세어져 `정차 6곳`(실제 2곳)이 된다(§5.4).
    final groups = RouteStopGroup.group(plan.stops);
    final assigned = plan.stops.length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              busName: widget.busName ?? '버스 #${plan.busId}',
              direction: plan.direction,
              status: plan.status,
            ),
            const SizedBox(height: AppSpacing.smd),
            _CapacityBar(assigned: assigned, seatCapacity: widget.seatCapacity),
            const SizedBox(height: AppSpacing.smd),
            Text(
              '정차 ${groups.length}곳 · ${plan.distanceLabel} · ${plan.durationLabel}',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            // 날짜·회차는 카드가 세로로 쌓이는 목록이라 자릿수를 고정한다(§2.1 Mono).
            Text(
              '${plan.serviceDateLabel} · ${plan.version}회차',
              style: AppTypography.mono(
                context,
              ).copyWith(color: scheme.onSurfaceVariant),
            ),
            if (groups.isEmpty) ...[
              const SizedBox(height: AppSpacing.smd),
              Text(
                '이 버스에 배정된 학생이 없습니다.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              _RosterToggle(
                label: '배정 학생 $assigned명',
                expanded: _expanded,
                onToggle: () => setState(() => _expandedOverride = !_expanded),
              ),
              if (_expanded)
                for (final group in groups)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _StopGroupRow(
                      group: group,
                      studentNameOf: widget.studentNameOf,
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 호차명 · 방향 · 승인 단계.
class _Header extends StatelessWidget {
  const _Header({
    required this.busName,
    required this.direction,
    required this.status,
  });

  final String busName;
  final RouteDirection direction;
  final RoutePlanStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 글자 확대 200% 에서도 상태 칩이 밀려나지 않게 좌측만 접히게 둔다(§7-5).
        Expanded(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_bus, size: 18, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      busName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                direction.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        RoutePlanStatusChip(status: status),
      ],
    );
  }
}

/// 정원 대비 배정 — `4 / 4석` + 진행바.
///
/// 배차 알고리즘은 정원을 **하드 제약**으로 지키므로(검증 보고서 V1·V2) 여기서
/// 초과가 나올 일은 없다. 그래도 초과 경로를 남겨 둔 건, 좌석 수를 나중에 줄인
/// 경우처럼 명부와 계획이 어긋난 상태를 조용히 감추지 않기 위해서다.
class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.assigned, required this.seatCapacity});

  final int assigned;
  final int? seatCapacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final capacity = seatCapacity;

    final countStyle = theme.textTheme.titleSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // 좌석 수를 모른다 — 칸을 비우고 배정 인원만 낸다. 진행바를 0 으로 그리면
    // "정원이 0이라 다 넘쳤다"로 읽힌다.
    if (capacity == null) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('배정 $assigned명', style: countStyle),
          const AppTag(label: '정원 정보 없음', tone: AppTone.neutral),
        ],
      );
    }

    final over = assigned > capacity;
    final full = assigned >= capacity;
    // 가득 참은 고장이 아니라 **판단 사항**이라 warning 이다. error 는 초과에만 쓴다.
    final tone = over
        ? AppTone.error
        : full
        ? AppTone.warning
        : AppTone.primary;
    final (String icon, String label) = over
        ? ('!', '정원 초과')
        : full
        ? ('●', '정원 가득')
        : ('○', '여유 ${capacity - assigned}석');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$assigned / $capacity석', style: countStyle),
            // 색만으로 구분하지 않는다(§0-1) — 아이콘·한글 라벨을 항상 같이 낸다.
            AppStatusChip(icon: icon, label: label, tone: tone),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          child: LinearProgressIndicator(
            value: (assigned / capacity).clamp(0.0, 1.0),
            minHeight: AppSpacing.sm,
            backgroundColor: scheme.surfaceContainerHigh,
            color: tone.solid(context),
          ),
        ),
      ],
    );
  }
}

/// 학생 명단 접기/펴기 — **줄 전체가 48dp 타깃**이다.
class _RosterToggle extends StatelessWidget {
  const _RosterToggle({
    required this.label,
    required this.expanded,
    required this.onToggle,
  });

  final String label;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            constraints: const BoxConstraints(minHeight: AppTouch.min),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 정차 한 곳에서 타는 학생들 — `1번 정차` + 이름 나열(§5.4).
class _StopGroupRow extends StatelessWidget {
  const _StopGroupRow({required this.group, required this.studentNameOf});

  final RouteStopGroup group;
  final String Function(int studentId)? studentNameOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 이름을 모르면 `#7` 로 남긴다 — `학생` 으로 얼버무리면 명부가 덜 불러와진
    // 상태를 배정 오류로 오해한다(`StudentDirectory` 와 같은 규칙).
    String nameOf(int id) => studentNameOf?.call(id) ?? '#$id';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        // 카드(20) 안의 한 줄이라 12 다(§3.2).
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      // 이름이 길어져도 태그를 밀어내지 않게 Wrap 을 쓴다(§7-5).
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 제목은 도메인이 정한다 — 운행 전이라 `1번 정차` 로 나온다(§5.4-6).
          AppTag(label: group.title, tone: AppTone.neutral),
          Text(
            [for (final id in group.studentIds) nameOf(id)].join(', '),
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// 버스 간 **운행거리 비교** — 이 화면이 확정 전에 드러내야 할 핵심이다.
///
/// 배차 알고리즘은 정원만 맞추고 **거리 균형은 맞추지 않는다**
/// (`backend/report/2026-07-29-route-optimization-verification.md` L1·L2).
/// depot 기준 방위각으로 자른 뒤 버스 id 순서대로 좌석수만큼 채우기 때문에,
/// 정원이 큰 버스가 우연히 넓은 부채꼴을 맡으면 거리가 두 배로 벌어진다
/// (실측: 4석 3,500m vs 6석 7,529m).
///
/// **고장이 아니다.** 그래서 `AppTone.error` 로 그리지 않는다 — 빨강으로 띄우면
/// 관리자가 제안을 다시 받는다. 다시 받아도 결과는 같다. 여기서 할 일은
/// "이대로 둘지 손으로 조정할지"를 관리자가 정하게 만드는 것뿐이다.
class BusDistanceComparison extends StatelessWidget {
  const BusDistanceComparison({super.key, required this.plans, this.busNameOf});

  final List<RoutePlan> plans;

  /// `busId → 호차명`. null 이면 `버스 #id`.
  final String Function(int busId)? busNameOf;

  @override
  Widget build(BuildContext context) {
    // 한 대뿐이면 비교할 대상이 없다 — 막대 하나는 정보가 아니라 장식이다.
    if (plans.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final spread = BusDistanceSpread.of(plans);
    String nameOf(int id) => busNameOf?.call(id) ?? '버스 #$id';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '버스별 운행거리',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final plan in plans)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _DistanceBar(
              busName: nameOf(plan.busId),
              distanceLabel: plan.distanceLabel,
              // 가장 긴 노선을 1 로 두고 나머지를 상대 길이로 그린다.
              fraction: spread.longestM <= 0
                  ? 0
                  : plan.totalDistanceM / spread.longestM,
              // 균형이 잡혀 있으면 최장/최단을 표시하지 않는다 — 정상 상태에
              // 표식을 붙이면 매번 뭔가 잘못된 것처럼 읽힌다.
              rank: !spread.isUneven
                  ? null
                  : plan.totalDistanceM == spread.longestM
                  ? _DistanceRank.longest
                  : plan.totalDistanceM == spread.shortestM
                  ? _DistanceRank.shortest
                  : null,
            ),
          ),
        if (spread.isUneven) _UnevenNotice(spread: spread),
      ],
    );
  }
}

enum _DistanceRank { longest, shortest }

class _DistanceBar extends StatelessWidget {
  const _DistanceBar({
    required this.busName,
    required this.distanceLabel,
    required this.fraction,
    required this.rank,
  });

  final String busName;
  final String distanceLabel;
  final double fraction;
  final _DistanceRank? rank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLongest = rank == _DistanceRank.longest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 호차명이 길거나 글자가 커지면 거리 표기 아래로 접힌다(§7-5).
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(busName, style: theme.textTheme.bodyLarge),
            // 막대 색만으로는 어느 게 최장인지 못 읽는다(§0-1).
            if (rank != null)
              AppTag(
                label: isLongest ? '최장' : '최단',
                tone: isLongest ? AppTone.warning : AppTone.neutral,
              ),
            Text(
              distanceLabel,
              style: AppTypography.mono(
                context,
              ).copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: AppSpacing.sm,
            backgroundColor: scheme.surfaceContainerHigh,
            color: isLongest
                ? AppTone.warning.solid(context)
                : AppTone.primary.solid(context),
          ),
        ),
      ],
    );
  }
}

/// 거리 격차 안내 — **경고지 오류가 아니다.**
class _UnevenNotice extends StatelessWidget {
  const _UnevenNotice({required this.spread});

  final BusDistanceSpread spread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = AppTone.warning.onContainer(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: AppTone.warning.container(context),
        // 배너는 카드가 아니라 문장 덩어리다(§3.2).
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.balance, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '가장 긴 노선이 가장 짧은 노선의 ${spread.ratioLabel}입니다. '
              '배차는 정원만 맞추고 버스 간 운행거리는 맞추지 않습니다 — '
              '기사 부담을 나누려면 확정 전에 배정을 조정하세요.',
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// 버스 간 운행거리 격차.
///
/// 도메인이 아니라 여기 있는 이유: 서버가 주는 값이 아니라 **화면이 관리자에게
/// 무엇을 알릴지 정하는 기준**이다. 임계값(1.5배)도 알고리즘이 아니라 표기 규칙이다.
class BusDistanceSpread {
  const BusDistanceSpread({
    required this.count,
    required this.longestM,
    required this.shortestM,
  });

  /// 이 배율 이상 벌어지면 문구로 알린다. 실측(3,500m ↔ 7,529m = 2.2배)이
  /// 걸리고, 같은 지역을 나눠 맡는 정상적인 편차(1.2~1.3배)는 안 걸리는 값이다.
  static const double unevenRatio = 1.5;

  final int count;
  final double longestM;
  final double shortestM;

  factory BusDistanceSpread.of(Iterable<RoutePlan> plans) {
    final distances = [for (final plan in plans) plan.totalDistanceM];
    if (distances.isEmpty) {
      return const BusDistanceSpread(count: 0, longestM: 0, shortestM: 0);
    }
    return BusDistanceSpread(
      count: distances.length,
      longestM: distances.reduce(math.max),
      shortestM: distances.reduce(math.min),
    );
  }

  /// 최단 대비 최장 배율. 최단이 0 이면 비교가 성립하지 않아 1 로 둔다 —
  /// 0 으로 나눠 `Infinity` 를 화면에 흘리지 않는다.
  double get ratio => shortestM <= 0 ? 1 : longestM / shortestM;

  bool get isUneven => count >= 2 && ratio >= unevenRatio;

  String get ratioLabel => '${ratio.toStringAsFixed(1)}배';
}
