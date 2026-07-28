import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/map/impl/flutter_map_adapter.dart';
import '../../../../core/map/spec/map_view_adapter.dart';
import '../../../../core/ui/async_section.dart';
import '../../../../core/ui/empty_view.dart';
import '../../application/bus_monitor_controller.dart';
import '../widget/monitored_bus_tile.dart';

/// 관리자 관제 지도(C9) — 학원의 버스 최신 위치를 3초마다 폴링해 지도에 얹는다.
///
/// ⚠️ **WebSocket push 가 없다.** STOMP 의 location 채널은 전부 *학생* 위치라
/// 버스는 REST 폴링이 유일한 경로다(계획서 §3.6). 주기는
/// [BusMonitorController.pollInterval] 한 곳에서만 정한다.
///
/// 관리자는 데스크톱에서 보므로 넓은 화면에서는 지도에 가로 폭을 몰아주고
/// 버스 목록을 옆에 세운다.
class AdminMonitorScreen extends ConsumerStatefulWidget {
  const AdminMonitorScreen({super.key});

  @override
  ConsumerState<AdminMonitorScreen> createState() => _AdminMonitorScreenState();
}

class _AdminMonitorScreenState extends ConsumerState<AdminMonitorScreen>
    with WidgetsBindingObserver {
  /// 목록 패널 폭. 지도가 주인공이라 목록은 읽을 수 있는 최소치만 가져간다.
  static const _sidePanelWidth = 320.0;

  /// 좁은 화면에서 지도 아래에 두는 목록 높이.
  static const _bottomPanelHeight = 220.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 보이지 않는 탭에서 3초마다 요청을 계속 던질 이유가 없다.
    final controller = ref.read(busMonitorControllerProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      controller.resume();
    } else {
      controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitor = ref.watch(busMonitorControllerProvider);

    return AsyncSection<BusMonitorState>(
      value: monitor,
      loadingLabel: '버스 위치를 불러오는 중',
      onRetry: () => ref.read(busMonitorControllerProvider.notifier).refresh(),
      data: _buildMonitor,
    );
  }

  Widget _buildMonitor(BusMonitorState state) {
    final now = DateTime.now();
    final isWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.compact;

    final map = _MapPanel(state: state);
    final list = _BusListPanel(state: state, now: now);

    return Column(
      children: [
        _MonitorHeader(state: state),
        if (state.pollErrorMessage != null)
          _PollWarning(message: state.pollErrorMessage!),
        Expanded(
          child: isWide
              ? Row(
                  children: [
                    Expanded(child: map),
                    const VerticalDivider(width: 1),
                    SizedBox(width: _sidePanelWidth, child: list),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: map),
                    const Divider(height: 1),
                    SizedBox(height: _bottomPanelHeight, child: list),
                  ],
                ),
        ),
      ],
    );
  }
}

/// 지도 — 버스 마커만 얹는다.
///
/// 버스를 하나 고르면 **그 버스만** 그린다. 지도 어댑터가 좌표에 맞춰 자동으로
/// 확대하므로, 마커 색을 바꾸는 것보다 확실하게 "지금 보는 대상"이 드러난다
/// (마커 종류를 늘리려면 `core/map` 을 고쳐야 하는데 그건 이 화면의 일이 아니다).
class _MapPanel extends ConsumerWidget {
  const _MapPanel({required this.state});

  final BusMonitorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adapter = ref.watch(mapViewAdapterProvider);
    final controller = ref.read(busMonitorControllerProvider.notifier);

    final selected = state.selectedBus;
    final shown = (selected != null && selected.hasPosition)
        ? [selected]
        : state.buses.where((bus) => bus.hasPosition);

    final markers = [
      for (final bus in shown)
        MapMarkerSpec(
          point: bus.position!.point,
          kind: MapMarkerKind.bus,
          label: bus.name,
          onTap: () => controller.select(bus.busId),
        ),
    ];

    if (markers.isEmpty) {
      // 버스는 등록돼 있는데 아직 아무도 좌표를 보내지 않은 상태 — 관리자가 할 일은
      // 기사 쪽 위치 전송을 켜는 것이므로, 목록의 "등록된 버스가 없습니다"와 구분한다.
      return const EmptyView(
        icon: Icons.location_searching,
        title: '아직 위치를 보고한 버스가 없습니다',
        description: '기사 앱에서 위치 전송을 켜면 이곳에 표시됩니다.',
      );
    }
    return adapter.build(markers: markers);
  }
}

class _BusListPanel extends ConsumerWidget {
  const _BusListPanel({required this.state, required this.now});

  final BusMonitorState state;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(busMonitorControllerProvider.notifier);

    if (state.buses.isEmpty) {
      // 지도의 빈 상태와 원인이 다르다 — 이쪽은 관제할 대상 자체가 없는 상태다.
      return const EmptyView(
        icon: Icons.directions_bus_outlined,
        title: '등록된 버스가 없습니다',
        description: '버스 관리에서 버스를 먼저 등록하면 이곳에서 위치를 볼 수 있습니다.',
      );
    }

    return ListView.separated(
      itemCount: state.buses.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final bus = state.buses[index];
        return MonitoredBusTile(
          bus: bus,
          now: now,
          selected: bus.busId == state.selectedBusId,
          onTap: () => controller.select(bus.busId),
        );
      },
    );
  }
}

class _MonitorHeader extends ConsumerWidget {
  const _MonitorHeader({required this.state});

  final BusMonitorState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(busMonitorControllerProvider.notifier);
    final seconds = BusMonitorController.pollInterval.inSeconds;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '버스 ${state.buses.length}대 · 위치 수신 ${state.positionedCount}대',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          _HeaderChip(
            icon: state.pausedByLifecycle ? Icons.pause : Icons.autorenew,
            label: state.pausedByLifecycle ? '갱신 일시중지' : '$seconds초마다 갱신',
          ),
          // 플랫폼 관리자는 소속 학원이 없어 고정값을 쓴다 — 다른 학원을 보고 있다고
          // 오해하지 않도록 화면에 명시한다(계획서 §8 D3).
          _HeaderChip(
            icon: Icons.apartment,
            label: state.isTenantFallback
                ? '학원 #${state.tenantId} (고정값)'
                : '학원 #${state.tenantId}',
          ),
          if (state.selectedBusId != null)
            ActionChip(
              avatar: const Icon(Icons.zoom_out_map, size: 16),
              label: const Text('전체 보기'),
              onPressed: () => controller.select(null),
            ),
          IconButton(
            tooltip: '전체 새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: controller.refresh,
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.hintColor),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

/// 폴링이 한 번 실패했을 때. **지도는 마지막 좌표를 그대로 유지한다** —
/// 실패마다 화면을 비우면 깜빡이기만 하고 정보는 줄어든다.
class _PollWarning extends StatelessWidget {
  const _PollWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem, size: 16, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              // 서버가 준 문구를 그대로 쓴다(컨벤션 §7-2).
              '$message — 마지막으로 받은 위치를 표시하고 있습니다',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
