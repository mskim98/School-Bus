import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/map/impl/flutter_map_adapter.dart';
import '../../../../core/map/spec/map_view_adapter.dart';
import '../../../../core/ui/error_message.dart';
import '../../../location/presentation/widget/driver_location_card.dart';
import '../../application/driver_route_controller.dart';
import '../../domain/route_plan.dart';
import '../widget/route_stop_tile.dart';

/// 기사: 오늘의 노선 — 지도(경로·정차) + 정차 순서 목록.
///
/// 운전석에서 잠깐 보는 화면이라 "지금 어디로 가야 하는지"를 위쪽에 크게 둔다.
class DriverRouteScreen extends ConsumerWidget {
  const DriverRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = ref.watch(driverRouteControllerProvider);

    return routeState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Centered(
        child: ErrorBanner(
          error: error,
          onRetry: () =>
              ref.read(driverRouteControllerProvider.notifier).refresh(),
        ),
      ),
      data: (state) {
        // "버스가 없다"와 "노선이 없다"를 나눠 안내한다 — 기사가 할 행동이 다르다.
        if (!state.hasBus) {
          return const _EmptyState(
            icon: Icons.no_transfer_outlined,
            title: '배차된 버스가 없습니다',
            description: '관리자에게 버스 배차를 요청해 주세요.',
          );
        }

        final content = state.isEmpty
            ? const _EmptyState(
                icon: Icons.route_outlined,
                title: '오늘 배포된 노선이 없습니다',
                description: '관리자가 배차를 확정하면 이곳에 노선이 표시됩니다.',
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

    return Column(
      children: [
        // 등원/하원이 둘 다 배포됐을 때만 전환 탭을 보여준다.
        if (directions.length > 1)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: SegmentedButton<RouteDirection>(
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

        _RouteSummary(plan: plan),

        // 지도가 화면의 절반 정도를 쓴다 — 목록만으로는 방향 감각이 안 잡힌다.
        Expanded(
          flex: 5,
          child: adapter.build(
            routes: [MapRouteSpec(points: plan.path)],
            markers: _markersOf(plan),
          ),
        ),

        Expanded(
          flex: 4,
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(driverRouteControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: plan.stops.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => RouteStopTile(
                stop: plan.stops[index],
                isNext: index == 0,
                isLast: index == plan.stops.length - 1,
              ),
            ),
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

/// 총 거리·소요·정차 수 — 운행 전체 감을 한 줄로 준다.
class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.plan});

  final RoutePlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          _Metric(label: '방향', value: plan.direction.label),
          _Metric(label: '정차', value: '${plan.stops.length}곳'),
          _Metric(label: '거리', value: plan.distanceLabel),
          _Metric(label: '소요', value: plan.durationLabel),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Centered(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child),
  );
}
