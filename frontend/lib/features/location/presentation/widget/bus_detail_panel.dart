import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/async_section.dart';
import '../../../../core/ui/error_message.dart';
import '../../../../core/ui/skeleton_box.dart';
import '../../../bus/application/bus_directory.dart';
import '../../../drivesession/application/admin_bus_session_provider.dart';
import '../../../drivesession/domain/drive_session.dart';
import '../../../rideevent/application/admin_bus_ride_events_provider.dart';
import '../../../routing/application/admin_bus_route_provider.dart';
import '../../../routing/domain/route_plan.dart';
import '../../../routing/domain/route_stop_group.dart';
import '../../application/bus_operation_status.dart';
import '../../domain/monitored_bus.dart';
import 'monitored_bus_tile.dart';

/// 관제 지도에서 **고른 버스 한 대**의 상세.
///
/// 지도는 "어디 있나"만 답한다. 관리자가 실제로 판단하려면 그 옆에
/// **누가 몰고 있고 · 지금 운행 중인가 · 몇 명 타고 있나**가 같이 있어야 한다.
///
/// **다른 feature 의 조회를 화면에서 조립한다**(컨벤션 C-1 예외). 버스 명부는
/// `bus`, 운행 세션은 `drivesession`, 승하차 기록은 `rideevent`, 노선은 `routing`
/// 에 있는데 이걸 상태 계층에서 엮으면 컨트롤러들이 서로를 다시 빌드시킨다.
/// 그래서 **읽기(`ref.watch`)만** 하고, 상대가 로딩·에러·없음이어도 이 패널의
/// 나머지 부분은 그대로 그린다.
///
/// ⚠️ 이 화면은 3초마다 위치를 다시 부른다(폴링). 여기서 쓰는 조회는 전부
/// **버스 id 를 키로 하는 `family`** 라 폴링으로 위젯이 다시 그려져도 재요청이
/// 나가지 않는다 — 선택이 바뀔 때만 받는다.
class BusDetailPanel extends ConsumerWidget {
  const BusDetailPanel({
    super.key,
    required this.bus,
    required this.tenantId,
    required this.now,
    this.onClose,
  });

  final MonitoredBus bus;
  final int tenantId;

  /// 신선도·경과 시간 기준 시각. 위젯마다 `DateTime.now()` 를 따로 부르면
  /// 같은 화면 안에서 초가 어긋나 보인다.
  final DateTime now;

  final VoidCallback? onClose;

  /// 지도에 그릴 노선 한 건을 고른다.
  ///
  /// 운행 중이면 **그 방향**(등원/하원)의 노선을 그린다 — 하원 운행 중에 등원
  /// 경로를 그리면 관리자가 버스가 반대로 간다고 읽는다. 운행 중이 아니면 받은
  /// 순서대로 첫 번째(등원 우선)를 그리고, 패널이 어느 방향을 그렸는지 밝힌다.
  ///
  /// 두 방향을 겹쳐 그리지 않는 이유: 정차 마커 번호가 두 벌이 되어 지도에서
  /// 같은 숫자가 두 곳에 찍힌다.
  static RoutePlan? planFor(List<RoutePlan> plans, DriveDirection? direction) {
    if (plans.isEmpty) return null;
    if (direction != null) {
      for (final plan in plans) {
        if (plan.direction.wireName == direction.wireName) return plan;
      }
    }
    return plans.first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final query = (tenantId: tenantId, busId: bus.busId);
    // 명부가 아직 안 왔거나 실패해도 패널은 뜬다 — 그때는 정원·노선명만 빈다.
    final busInfo = ref.watch(busDirectoryProvider(tenantId)).value?.find(
      bus.busId,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _Header(bus: bus, onClose: onClose),
        const SizedBox(height: AppSpacing.sm),
        _BusFacts(bus: bus, seatCapacity: busInfo?.seatCapacity,
            routeName: busInfo?.routeName),
        const SizedBox(height: AppSpacing.lg),
        Text('운행 상태', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AsyncSection<DriveSession?>(
          value: ref.watch(adminBusSessionProvider(query)),
          loadingLabel: '운행 상태를 불러오는 중',
          loading: () => const SkeletonList(
            itemCount: 2,
            itemHeight: 40,
            padding: EdgeInsets.zero,
          ),
          onRetry: () => ref.invalidate(adminBusSessionProvider(query)),
          data: (session) => _OperationSection(
            session: session,
            tenantId: tenantId,
            busId: bus.busId,
            assignedCount: busInfo?.assignedCount,
            now: now,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('노선', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _RouteSection(tenantId: tenantId, busId: bus.busId),
        const SizedBox(height: AppSpacing.lg),
        Text('위치', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _FreshnessLine(bus: bus, now: now),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.bus, this.onClose});

  final MonitoredBus bus;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onClose = this.onClose;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bus.name.isEmpty ? '버스 ${bus.busId}' : bus.name,
                style: theme.textTheme.titleMedium,
              ),
              if (bus.plateNumber != null && bus.plateNumber!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  bus.plateNumber!,
                  style: AppTypography.mono(context).copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            tooltip: '선택 해제',
            onPressed: onClose,
            icon: const Icon(Icons.close),
            constraints: const BoxConstraints(
              minWidth: AppTouch.min,
              minHeight: AppTouch.min,
            ),
          ),
      ],
    );
  }
}

/// 기사·정원·노선명. 200% 배율에서도 접히도록 [Wrap] 이다(§7-5).
class _BusFacts extends StatelessWidget {
  const _BusFacts({
    required this.bus,
    this.seatCapacity,
    this.routeName,
  });

  final MonitoredBus bus;
  final int? seatCapacity;
  final String? routeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final driver = bus.driverName;
    final routeName = this.routeName;
    final seatCapacity = this.seatCapacity;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 기사가 없으면 "미배차" — 위치가 안 오는 이유가 대개 이것이다.
        Text(
          driver == null || driver.isEmpty ? '기사 미배차' : '기사 $driver',
          style: style,
        ),
        // 정원을 모르면 `0석` 이 아니라 아예 빼둔다 — 0 은 "정원 초과"로 읽힌다.
        if (seatCapacity != null) Text('정원 $seatCapacity석', style: style),
        if (routeName != null && routeName.isNotEmpty)
          AppTag(label: routeName, tone: AppTone.neutral),
      ],
    );
  }
}

/// 운행 상태 + 인원. 승하차 기록은 **세션이 있을 때만** 부른다.
class _OperationSection extends ConsumerWidget {
  const _OperationSection({
    required this.session,
    required this.tenantId,
    required this.busId,
    required this.assignedCount,
    required this.now,
  });

  final DriveSession? session;
  final int tenantId;
  final int busId;
  final int? assignedCount;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = this.session;

    // 운행 이력이 없으면 기록을 부를 이유가 없다 — 셀 구간 자체가 없다.
    final eventsQuery = session == null
        ? null
        : (tenantId: tenantId, busId: busId, serviceDate: session.serviceDate);
    final events = eventsQuery == null
        ? null
        : ref.watch(adminBusRideEventsProvider(eventsQuery));

    final status = BusOperationStatus.of(
      session: session,
      // 로딩·실패면 null 을 넘긴다. 빈 목록(`받았는데 없다`)과 구분해야
      // "아직 모른다"가 `0명 탑승` 으로 확정 표시되지 않는다.
      events: events?.value,
      assignedCount: assignedCount,
      now: now,
    );

    final tone = switch (status.phase) {
      BusOperationPhase.notStarted => AppTone.neutral,
      BusOperationPhase.inProgress => AppTone.primary,
      BusOperationPhase.completed => AppTone.success,
    };
    final direction = status.direction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppStatusChip(
              icon: status.phase.icon,
              label: status.phase.label,
              tone: tone,
            ),
            if (direction != null)
              AppTag(label: direction.label, tone: AppTone.neutral),
          ],
        ),
        if (status.phase == BusOperationPhase.notStarted) ...[
          const SizedBox(height: AppSpacing.sm),
          _Caption(
            session == null
                ? '오늘 시작된 운행이 없습니다. 기사가 운행을 시작하면 여기에 표시됩니다.'
                : '오늘 시작된 운행이 없습니다. 마지막 운행은 ${session.serviceDate.month}월 ${session.serviceDate.day}일입니다.',
          ),
        ],
        if (status.session != null) ...[
          const SizedBox(height: AppSpacing.smd),
          _MetricRow(
            metrics: [
              (label: '시작', value: _timeLabel(status.session!.startedAt)),
              (
                label: status.phase == BusOperationPhase.completed
                    ? '소요'
                    : '경과',
                value: _durationLabel(status.elapsed),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.smd),
        _MetricRow(
          metrics: [
            // 서버 필드명이 `onboard` 라 탑승 인원처럼 보이지만 **배정 명부 크기**다.
            (
              label: '예정 인원',
              value: assignedCount == null ? '—' : '$assignedCount명',
            ),
            (
              label: '현재 탑승',
              value: status.onboardCount == null
                  ? '—'
                  : '${status.onboardCount}명',
            ),
            (label: '처리', value: _progressLabel(status)),
          ],
        ),
        if (events != null) ...[
          if (events.hasError && !events.hasValue) ...[
            const SizedBox(height: AppSpacing.sm),
            ErrorBanner(
              error: events.error!,
              onRetry: () =>
                  ref.invalidate(adminBusRideEventsProvider(eventsQuery!)),
            ),
          ] else if (events.isLoading && !events.hasValue) ...[
            const SizedBox(height: AppSpacing.sm),
            const _Caption('탑승 인원을 세는 중입니다.'),
          ] else if (status.countsKnown && status.onboardCount == 0) ...[
            const SizedBox(height: AppSpacing.sm),
            const _Caption('이번 운행에서 아직 승차한 학생이 없습니다.'),
          ],
        ],
      ],
    );
  }

  /// `처리 2/3` — 분모는 배정 인원이다. 배정 인원을 모르면 분모를 짓지 않는다.
  static String _progressLabel(BusOperationStatus status) {
    final processed = status.processedCount;
    if (processed == null) return '—';
    final total = status.assignedCount;
    return total == null ? '$processed명' : '$processed/$total';
  }

  /// `14:05` — 서버가 준 벽시계 시각을 그대로 쓴다(오프셋이 없다).
  static String _timeLabel(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// `12분` · `1시간 5분`. 모르면 `—`(기기·서버 시계가 어긋난 경우).
  static String _durationLabel(Duration? duration) {
    if (duration == null) return '—';
    final minutes = duration.inMinutes;
    if (minutes < 1) return '1분 미만';
    if (minutes < 60) return '$minutes분';
    return '${minutes ~/ 60}시간 ${minutes % 60}분';
  }
}

/// 배포된 노선 요약. 지도에 실제로 그려지는 건 [BusDetailPanel.planFor] 가 고른 하나다.
class _RouteSection extends ConsumerWidget {
  const _RouteSection({required this.tenantId, required this.busId});

  final int tenantId;
  final int busId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (tenantId: tenantId, busId: busId);
    final plans = ref.watch(adminBusRoutePlansProvider(query));
    final session = ref.watch(adminBusSessionProvider(query)).value;

    if (plans.hasError && !plans.hasValue) {
      return ErrorBanner(
        error: plans.error!,
        onRetry: () => ref.invalidate(adminBusRoutePlansProvider(query)),
      );
    }
    if (!plans.hasValue) {
      return const SkeletonBox(height: AppTouch.min);
    }

    final list = plans.requireValue;
    if (list.isEmpty) {
      // 노선이 없는 것과 못 받은 것은 다르다. 이건 아직 배차하지 않은 상태다.
      return const _Caption('배포된 노선이 없습니다. 배차 화면에서 노선을 배포하면 지도에 경로가 그려집니다.');
    }

    final drawn = BusDetailPanel.planFor(list, session?.direction);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final plan in list) ...[
          if (plan != list.first) const SizedBox(height: AppSpacing.sm),
          _RouteLine(plan: plan, drawnOnMap: identical(plan, drawn)),
        ],
      ],
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.plan, required this.drawnOnMap});

  final RoutePlan plan;
  final bool drawnOnMap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 마커와 같은 규칙으로 묶어야 "정차 3곳"이 지도의 마커 수와 맞는다(§5.4).
    final stopCount = RouteStopGroup.group(plan.stops).length;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(plan.direction.label, style: theme.textTheme.bodyMedium),
        Text(
          '정차 $stopCount곳 · ${plan.distanceLabel} · ${plan.durationLabel}',
          style: AppTypography.mono(
            context,
          ).copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        // 어느 노선이 지도에 그려졌는지 글자로 밝힌다 — 선 색만으로는 알 수 없다(§0-1).
        if (drawnOnMap) const AppTag(label: '지도 표시 중', tone: AppTone.primary),
      ],
    );
  }
}

/// 마지막 좌표를 받은 지 얼마나 됐는가. 오래됐으면 그 사실을 **문장으로** 알린다.
class _FreshnessLine extends StatelessWidget {
  const _FreshnessLine({required this.bus, required this.now});

  final MonitoredBus bus;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final position = bus.position;
    if (position == null) {
      return const _Caption('아직 위치를 보고한 적이 없습니다. 기사 앱에서 위치 전송을 켜야 합니다.');
    }

    final staleness = bus.staleness(now) ?? Duration.zero;
    final isStale = staleness > MonitoredBusTile.staleAfter;
    final seconds = staleness.inSeconds;
    final elapsed = seconds < 60
        ? '$seconds초'
        : (staleness.inMinutes < 60
              ? '${staleness.inMinutes}분'
              : '${staleness.inHours}시간');

    if (!isStale) {
      return _Caption('$elapsed 전에 받은 위치입니다 · 출처 ${position.origin.label}');
    }

    // 색만으로 알리지 않는다 — 아이콘 + 문장을 같이 낸다(§0-1).
    final foreground = AppTone.error.onContainer(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.smd,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppTone.error.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$elapsed 동안 새 위치가 오지 않았습니다 · 지도의 표시는 마지막 위치입니다',
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

/// 라벨 + 수치 묶음. 200% 배율에서 줄바꿈되도록 [Wrap] 이다(§7-5).
class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metrics});

  final List<({String label, String value})> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        for (final metric in metrics)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // 3초마다 갱신되므로 자릿수를 고정한다(§2.1).
              Text(metric.value, style: AppTypography.mono(context)),
            ],
          ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.caption(context));
}
