import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/map/spec/map_view_adapter.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/async_section.dart';
import '../../../../core/ui/empty_view.dart';
import '../../../../core/ui/skeleton_box.dart';
import '../../application/bus_monitor_controller.dart';
import '../widget/monitored_bus_tile.dart';

/// 관리자 관제 지도(C9) — 학원의 버스 최신 위치를 3초마다 폴링해 지도에 얹는다.
///
/// ⚠️ **WebSocket push 가 없다.** STOMP 의 location 채널은 전부 *학생* 위치라
/// 버스는 REST 폴링이 유일한 경로다(계획서 §3.6). 주기는
/// [BusMonitorController.pollInterval] 한 곳에서만 정한다.
///
/// 넓은 화면에서는 **좌측 목록 + 우측 지도**다(디자인 시스템 §10). 목록이 먼저
/// 읽히는 순서라 "어느 버스를 볼지 고른 뒤 지도를 본다"는 동선과 맞는다.
class AdminMonitorScreen extends ConsumerStatefulWidget {
  const AdminMonitorScreen({super.key});

  @override
  ConsumerState<AdminMonitorScreen> createState() => _AdminMonitorScreenState();
}

class _AdminMonitorScreenState extends ConsumerState<AdminMonitorScreen>
    with WidgetsBindingObserver {
  /// 목록 패널 폭. 지도가 주인공이라 목록은 읽을 수 있는 최소치만 가져간다.
  static const _sidePanelWidth = 320.0;

  /// 아주 넓은 화면(§3 `AppBreakpoints.expanded`)에서만 한 단 넓힌다.
  /// 데스크톱에서 새로 정하는 건 **행 밀도뿐**이라 폭도 이 한 단계만 둔다(§10).
  static const _sidePanelWidthWide = 380.0;

  /// 좁은 화면에서 지도 아래에 두는 목록 높이.
  static const _bottomPanelHeight = 220.0;

  /// 관제 목록 한 줄의 대략 높이 — 자리표시자가 실제와 어긋나면 화면이 튄다.
  static const _tileHeight = 96.0;

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
      // 전체화면 스피너 대신 스켈레톤(§6). 지도 자리도 같이 잡아 둔다.
      loading: () => const SkeletonList(
        itemCount: 3,
        itemHeight: _tileHeight,
        header: _bottomPanelHeight,
      ),
      onRetry: () => ref.read(busMonitorControllerProvider.notifier).refresh(),
      data: _buildMonitor,
    );
  }

  Widget _buildMonitor(BusMonitorState state) {
    final now = DateTime.now();
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppBreakpoints.compact;

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
                    SizedBox(
                      width: width >= AppBreakpoints.expanded
                          ? _sidePanelWidthWide
                          : _sidePanelWidth,
                      child: list,
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: map),
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

    // 지도 자리는 비어 있을 때도 **지도 색**으로 남긴다(§5.3) — 표면색으로 칠하면
    // 카드처럼 보여서 "여기가 지도"라는 인지가 깨진다.
    return ColoredBox(
      color: context.appColors.mapBase,
      child: markers.isEmpty
          // 버스는 등록돼 있는데 아직 아무도 좌표를 보내지 않은 상태 — 관리자가 할 일은
          // 기사 쪽 위치 전송을 켜는 것이므로, 목록의 "등록된 버스가 없습니다"와 구분한다.
          ? const EmptyView(
              icon: Icons.location_searching,
              title: '아직 위치를 보고한 버스가 없습니다',
              description: '기사 앱에서 위치 전송을 켜면 이곳에 표시됩니다.',
            )
          : adapter.build(markers: markers),
    );
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
    final scheme = theme.colorScheme;
    final controller = ref.read(busMonitorControllerProvider.notifier);
    final seconds = BusMonitorController.pollInterval.inSeconds;
    final paused = state.pausedByLifecycle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        // 카드·툴바 표면(§1.1). 아래로 1px 선을 그어 지도와 경계를 만든다.
        color: scheme.surfaceContainer,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '버스 ${state.buses.length}대 · 위치 수신 ${state.positionedCount}대',
            style: theme.textTheme.titleSmall,
          ),
          // 갱신이 멈춰 있다는 건 "화면이 지금을 안 보여준다"는 뜻이라 주의 톤이다.
          AppStatusChip(
            icon: paused ? '⏸' : '↻',
            label: paused ? '갱신 일시중지' : '$seconds초마다 갱신',
            tone: paused ? AppTone.warning : AppTone.neutral,
          ),
          // 플랫폼 관리자는 소속 학원이 없어 고정값을 쓴다 — 다른 학원을 보고 있다고
          // 오해하지 않도록 화면에 명시한다(계획서 §8 D3).
          AppTag(label: '학원 #${state.tenantId}', tone: AppTone.neutral),
          if (state.isTenantFallback)
            const AppTag(label: '고정값', tone: AppTone.warning),
          if (state.selectedBusId != null)
            OutlinedButton.icon(
              onPressed: () => controller.select(null),
              icon: const Icon(Icons.zoom_out_map, size: 18),
              label: const Text('전체 보기'),
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

/// 폴링이 한 번 실패했을 때. **지도는 마지막 좌표를 그대로 유지한다** —
/// 실패마다 화면을 비우면 깜빡이기만 하고 정보는 줄어든다.
class _PollWarning extends StatelessWidget {
  const _PollWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final foreground = AppTone.error.onContainer(context);

    return Container(
      width: double.infinity,
      color: AppTone.error.container(context),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.sync_problem, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              // 서버가 준 문구를 그대로 쓴다(컨벤션 §7-2).
              '$message — 마지막으로 받은 위치를 표시하고 있습니다',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
