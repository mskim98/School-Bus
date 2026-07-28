import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/location/spec/location_source_kind.dart';
import '../../../../core/map/spec/map_view_adapter.dart';
import '../../application/driver_location_controller.dart';

/// 기사 화면에 얹는 위치 보고 패널(C8).
///
/// 관리자가 관제 지도에서 이 버스를 보고 있다는 뜻이라, **지금 보내고 있는지**를
/// 한눈에 알 수 있어야 한다 — 켜짐 표시·전송 횟수·실패 사유를 모두 노출한다.
/// 켜진 상태는 색만이 아니라 **맥동하는 점 + 문구**로도 낸다(디자인 시스템 §0-1,
/// 시안 `기사앱 MVP.dc.html` 125~136줄의 GPS pill).
///
/// [mockPath] 는 화면이 이미 조회해 둔 노선 좌표다. 상태 계층이 `routing` 기능을
/// 직접 참조하지 않도록(검사 C-1) 화면이 값으로 넘겨준다.
class DriverLocationCard extends ConsumerStatefulWidget {
  const DriverLocationCard({super.key, this.mockPath = const []});

  final List<GeoPoint> mockPath;

  @override
  ConsumerState<DriverLocationCard> createState() => _DriverLocationCardState();
}

class _DriverLocationCardState extends ConsumerState<DriverLocationCard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 화면을 벗어나면 전송을 멈춘다 — 보이지 않는 화면이 계속 좌표를 쏘면
    // 기사가 껐다고 생각한 뒤에도 관제 지도에 버스가 움직인다.
    ref.read(driverLocationControllerProvider.notifier).pause();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(driverLocationControllerProvider.notifier);
    switch (state) {
      case AppLifecycleState.resumed:
        controller.resume(mockPath: widget.mockPath);
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(driverLocationControllerProvider);
    final controller = ref.read(driverLocationControllerProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.smd,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: AppSpacing.lg,
                height: AppSpacing.lg,
                child: state.isReporting
                    ? const _ReportingPulse()
                    : Icon(
                        Icons.location_disabled_outlined,
                        size: 20,
                        color: scheme.outline,
                      ),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(child: _StatusText(state: state)),
              Switch(
                value: state.enabled,
                onChanged: (value) =>
                    controller.setEnabled(value, mockPath: widget.mockPath),
              ),
            ],
          ),

          // 출처 토글은 켜기 전에도 고를 수 있어야 한다 — 켠 뒤에 바꾸면
          // 권한 대화상자가 운행 중에 뜬다.
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: SegmentedButton<LocationSourceKind>(
              showSelectedIcon: false,
              // 기본 높이 40 은 금지값이다(§3.3) — 운전석에서 누르는 토글이라
              // 밀도를 줄이는 대신 48 을 지킨다.
              style: SegmentedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppTouch.min),
              ),
              segments: [
                for (final kind in LocationSourceKind.values)
                  ButtonSegment(
                    value: kind,
                    label: Text(kind.label),
                    tooltip: kind.description,
                  ),
              ],
              selected: {state.sourceKind},
              onSelectionChanged: (selection) => controller.setSourceKind(
                selection.first,
                mockPath: widget.mockPath,
              ),
            ),
          ),

          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.smd),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 18,
                      color: scheme.onErrorContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        // 서버·포트가 준 문구를 그대로 보여준다(컨벤션 §7-2).
                        state.errorMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 좌표가 나가고 있는 동안만 도는 맥동 점(시안 GPS pill).
///
/// 정지한 아이콘으로는 "켜 두기만 하고 실제로는 안 나가는" 상태와 구별이 안 된다.
class _ReportingPulse extends StatefulWidget {
  const _ReportingPulse();

  @override
  State<_ReportingPulse> createState() => _ReportingPulseState();
}

class _ReportingPulseState extends State<_ReportingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.appColors.success;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final ringSize = AppSpacing.sm + (AppSpacing.lg - AppSpacing.sm) * t;

        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - t) * 0.5,
              child: Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            Container(
              width: AppSpacing.sm,
              height: AppSpacing.sm,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
        );
      },
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.state});

  final DriverLocationState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final point = state.lastPoint;

    final (String title, String detail) = switch (state) {
      _ when state.isReporting => (
        '위치 전송 중 · 관제 지도에 표시',
        point == null
            ? '${DriverLocationController.reportInterval.inSeconds}초마다 보냅니다'
            : '${state.sentCount}회 전송 · ${_coordLabel(point)}',
      ),
      _ when state.pausedByLifecycle => ('전송 일시중지', '앱으로 돌아오면 다시 시작합니다'),
      _ => ('위치 전송 꺼짐', '켜면 관리자 관제 지도에 이 버스가 표시됩니다'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        // 좌표·전송 횟수는 갱신될 때 자릿수가 흔들리면 안 읽힌다(§2.2).
        Text(
          detail,
          style: AppTypography.mono(
            context,
          ).copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// 소수점 5자리면 약 1m 분해능이라 좌표가 실제로 움직이는지 눈으로 확인된다.
  static String _coordLabel(GeoPoint point) =>
      '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}';
}
