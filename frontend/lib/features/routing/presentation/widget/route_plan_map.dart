import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/map/spec/map_view_adapter.dart';
import '../../domain/route_plan.dart';

/// 노선 계획 여러 건을 한 지도에 겹쳐 그린다(배차 미리보기·노선 상세 공용).
///
/// 지도 라이브러리를 직접 알지 않는다 — [MapViewAdapter] 포트만 쓴다(컨벤션 §5).
/// 덕분에 `flutter_map` 을 다른 지도로 바꿔도 이 파일은 그대로다.
class RoutePlanMap extends ConsumerWidget {
  const RoutePlanMap({super.key, required this.plans});

  final List<RoutePlan> plans;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (plans.isEmpty) {
      return const _MapPlaceholder(message: '표시할 노선이 없습니다');
    }

    final adapter = ref.watch(mapViewAdapterProvider);
    return adapter.build(
      routes: [
        for (final plan in plans)
          if (plan.path.isNotEmpty) MapRouteSpec(points: plan.path),
      ],
      markers: _markers(),
    );
  }

  /// 정차 마커 + 학원(출발·도착지) 마커.
  ///
  /// 학원 좌표를 따로 주는 API 가 없다. 노선 경로가 학원에서 시작하므로
  /// 경로의 첫 점을 학원으로 본다(기사 화면과 같은 규칙).
  List<MapMarkerSpec> _markers() {
    return [
      for (final plan in plans) ...[
        if (plan.path.isNotEmpty)
          MapMarkerSpec(point: plan.path.first, kind: MapMarkerKind.depot),
        for (final stop in plan.stops)
          MapMarkerSpec(
            point: stop.point,
            kind: MapMarkerKind.stop,
            label: '${stop.seq}',
          ),
      ],
    ];
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
      ),
    );
  }
}
