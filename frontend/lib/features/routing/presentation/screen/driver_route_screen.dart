import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/map/spec/map_view_adapter.dart';
import '../../../../core/ui/app_action_button.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/async_section.dart';
import '../../../../core/ui/empty_view.dart';
import '../../../../core/ui/skeleton_box.dart';
import '../../../location/presentation/widget/driver_location_card.dart';
import '../../application/driver_route_controller.dart';
import '../../domain/route_plan.dart';
import '../widget/route_stop_tile.dart';

/// 기사: 오늘의 노선 — 지도(경로·정차) + 정차 순서 시트.
///
/// 운전석에서 잠깐 보는 화면이라 "지금 어디로 가야 하는지"를 위쪽에 크게 둔다
/// (`docs/DESIGN_BRIEF_DRIVER_MOBILE.md` §5.3, 시안 `기사앱 MVP.dc.html` 257~369줄).
class DriverRouteScreen extends ConsumerWidget {
  const DriverRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = ref.watch(driverRouteControllerProvider);

    return AsyncSection(
      value: routeState,
      onRetry: () => ref.read(driverRouteControllerProvider.notifier).refresh(),
      // 스피너 대신 스켈레톤 — **지도 자리를 큰 박스로 남겨** 로딩이 끝나도
      // 화면이 튀지 않게 한다(디자인 시스템 §6).
      loading: () => const SkeletonList(header: 200, itemHeight: 72),
      data: (state) {
        // "버스가 없다"와 "노선이 없다"를 나눠 안내한다 — 기사가 할 행동이 다르다.
        // 전자는 관리자에게 요청해야 하고, 후자는 기다리면 된다.
        if (!state.hasBus) {
          return const EmptyView(
            icon: Icons.no_transfer_outlined,
            title: '배차된 버스가 없습니다',
            description: '관리자에게 버스 배차를 요청해 주세요.',
          );
        }

        final content = state.isEmpty
            ? EmptyView(
                icon: Icons.route_outlined,
                title: '오늘 배포된 노선이 없습니다',
                description: '관리자가 배차를 확정하면 이곳에 노선이 표시됩니다.',
                action: AppActionButton(
                  label: '새로고침',
                  tone: AppTone.neutral,
                  outlined: true,
                  onPressed: () => ref
                      .read(driverRouteControllerProvider.notifier)
                      .refresh(),
                ),
              )
            : _RouteView(state: state);

        // 위치 보고 패널(C8)은 노선 유무와 상관없이 항상 위에 둔다 —
        // 노선이 없어도 실 GPS 로는 보고할 수 있고, 무엇보다 기사가
        // "내 위치가 나가고 있는지"를 항상 확인할 수 있어야 한다.
        return Column(
          children: [
            DriverLocationCard(mockPath: state.current?.path ?? const []),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

class _RouteView extends ConsumerWidget {
  const _RouteView({required this.state});

  final DriverRouteState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = state.current!;
    final adapter = ref.watch(mapViewAdapterProvider);
    final directions = state.availableDirections;
    final nextStop = plan.stops.isEmpty ? null : plan.stops.first;

    return Column(
      children: [
        // 등원/하원이 둘 다 배포됐을 때만 전환 탭을 보여준다.
        if (directions.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<RouteDirection>(
                // 기본 높이가 40 이라 터치 최소값(48)에 미달한다 — 흔들리는 차
                // 안에서 쓰는 화면이라 여기서 줄이지 않는다(§3.3).
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppTouch.min),
                ),
                segments: [
                  for (final d in directions)
                    ButtonSegment(value: d, label: Text(d.label)),
                ],
                selected: {plan.direction},
                onSelectionChanged: (selection) => ref
                    .read(driverRouteControllerProvider.notifier)
                    .select(selection.first),
              ),
            ),
          ),

        // 지도가 화면의 절반 정도를 쓰고, 정차 시트가 그 위로 올라온다 —
        // 목록만으로는 방향 감각이 안 잡히고, 지도만으로는 순서를 못 읽는다.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: adapter.build(
                      routes: [MapRouteSpec(points: plan.path)],
                      markers: _markersOf(plan),
                    ),
                  ),

                  // 지도 위 최상단 — 화면을 스크롤하지 않아도 다음 목적지가 보인다.
                  if (nextStop != null)
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      child: _NextStopCard(stop: nextStop),
                    ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: constraints.maxHeight * 0.55,
                    child: _StopSheet(plan: plan),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 정차 마커 + 학원(출발·도착지) 마커.
  ///
  /// 학원 좌표를 따로 주는 API 가 없다. 노선 경로가 학원에서 시작하므로
  /// 경로의 첫 점을 학원으로 본다.
  List<MapMarkerSpec> _markersOf(RoutePlan plan) {
    return [
      if (plan.path.isNotEmpty)
        MapMarkerSpec(point: plan.path.first, kind: MapMarkerKind.depot),
      for (final stop in plan.stops)
        MapMarkerSpec(
          point: stop.point,
          kind: MapMarkerKind.stop,
          label: '${stop.seq}',
        ),
    ];
  }
}

/// 지도 위에 떠 있는 "다음 정차" 카드(시안 296~306줄).
///
/// 시안은 그림자를 썼지만 우리는 **elevation 0 + `outlineVariant` 테두리**로 둔다
/// (§3.4 — 그림자는 지도 위 마커에만).
class _NextStopCard extends StatelessWidget {
  const _NextStopCard({required this.stop});

  final RouteStop stop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: scheme.surface,
        // 지도 위에 떠 있는 카드라 20 이다(§3.2). 정차 목록의 행(12)과
        // 같은 모서리면 카드와 항목이 같은 위계로 읽힌다.
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTone.primary.solid(context),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${stop.seq}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppTone.primary.onSolid(context),
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
                  '다음 정차',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '학생 #${stop.studentId}',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            stop.etaLabel,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// 지도 아래에서 올라오는 정차 순서 시트(시안 325~366줄).
class _StopSheet extends ConsumerWidget {
  const _StopSheet({required this.plan});

  final RoutePlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      child: Column(
        children: [
          // 지도와 시트의 경계를 알려주는 손잡이. 실제로 끌 수는 없지만
          // "아래는 목록"이라는 구분이 없으면 지도가 잘린 것처럼 보인다.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: _RouteSummary(plan: plan),
          ),
          const SizedBox(height: AppSpacing.smd),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '정차 순서',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '${plan.stops.length}곳',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(driverRouteControllerProvider.notifier).refresh(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                itemCount: plan.stops.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.smd),
                itemBuilder: (context, index) => RouteStopTile(
                  stop: plan.stops[index],
                  isNext: index == 0,
                  isLast: index == plan.stops.length - 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 총 거리·소요·정차 수 — 운행 전체 감을 한 줄로 준다(시안 329~342줄).
class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.plan});

  final RoutePlan plan;

  /// 이 배율을 넘으면 4열이 한 줄에 안 들어간다.
  ///
  /// 폰 폭 412 기준 칸당 약 65dp 인데, `12.4km`·`약 1시간 5분` 처럼 줄바꿈
  /// 지점이 없는 값이 200% 로 커지면 가로로 넘쳐 **잘린다**. 2×2 로 접는다.
  /// 같은 화면의 `RosterStudentTile` 이 쓰는 것과 같은 방식이다(§7-5).
  static const double _foldAboveTextScale = 1.15;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric(label: '방향', value: plan.direction.label),
      _Metric(label: '정차', value: '${plan.stops.length}곳'),
      _Metric(label: '거리', value: plan.distanceLabel),
      _Metric(label: '소요', value: plan.durationLabel),
    ];

    if (MediaQuery.textScalerOf(context).scale(1) <= _foldAboveTextScale) {
      return Row(children: _spaced(metrics));
    }
    return Column(
      children: [
        Row(children: _spaced(metrics.sublist(0, 2))),
        const SizedBox(height: AppSpacing.sm),
        Row(children: _spaced(metrics.sublist(2))),
      ],
    );
  }

  static List<Widget> _spaced(List<Widget> items) => [
    for (final (index, item) in items.indexed) ...[
      if (index > 0) const SizedBox(width: AppSpacing.sm),
      item,
    ],
  ];
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.smd),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // 숫자 폭이 흔들리지 않게 자릿수를 고정한다(§2.2 Mono 대체).
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
