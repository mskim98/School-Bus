import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/app_action_button.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/error_message.dart';
import '../../../../core/ui/skeleton_box.dart';
// ⚠️ feature 간 의존이 둘 있다(컨벤션 C-1). 이 화면 하나가 세 모듈의 사실을 모아
// 보여주기 때문이다 — 담당 버스는 bus, 운행 세션은 drivesession, 승하차 기록은
// 여기(rideevent). 원칙대로면 `shared/` 로 올려야 하지만, 이미 있던
// rideevent → drivesession 예외(`driver_roster_controller.dart`)와 같은 방향으로만
// 늘려 두고 역방향은 만들지 않는다.
import '../../../bus/application/my_bus_controller.dart';
import '../../../bus/domain/my_bus.dart';
import '../../../drivesession/application/drive_session_controller.dart';
import '../../../drivesession/domain/drive_session.dart';
import '../../application/last_run_summary_controller.dart';

/// 운행 시작 화면 — 기사가 하루를 여는 곳.
///
/// **건너뛸 수 있는 화면이 아니다.** 학생 이름은 운행 세션에서만 오므로
/// 여기서 시작을 누르기 전에는 명단이 존재하지 않는다. 그래서 방향 선택과 시작
/// 버튼을 화면의 주인공으로 두고, 그 사실을 안내 배너로 글자로도 남긴다.
///
/// 방향은 **명시적으로 고르게** 한다(기본 선택 없음). 등원/하원이 뒤바뀌면 명단의
/// 장소가 통째로 달라지고, 그 상태로 기록한 알림은 되돌릴 수 없다.
class DriveStartView extends ConsumerStatefulWidget {
  const DriveStartView({super.key, required this.state});

  final DriveSessionState state;

  @override
  ConsumerState<DriveStartView> createState() => _DriveStartViewState();
}

class _DriveStartViewState extends ConsumerState<DriveStartView> {
  DriveDirection? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final selected = _selected;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BusCard(busId: state.busId),
          if (state.lastCompleted case final done?) ...[
            const SizedBox(height: AppSpacing.smd),
            _LastRunSummary(session: done),
          ],
          const SizedBox(height: AppSpacing.lg),

          Text(
            '오늘 운행 방향을 선택하세요',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.smd),
          // 2지 선택을 나란히 둔다 — 위아래로 쌓으면 위쪽이 기본값처럼 읽힌다.
          // 두 카드 높이는 IntrinsicHeight 로 맞춘다(글자 200% 확대 대비).
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final direction in DriveDirection.values) ...[
                  if (direction != DriveDirection.values.first)
                    const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _DirectionCard(
                      direction: direction,
                      isSelected: selected == direction,
                      onTap: state.isSubmitting
                          ? null
                          : () => setState(() => _selected = direction),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _GateNotice(),

          if (state.actionError case final error?) ...[
            const SizedBox(height: AppSpacing.md),
            ErrorBanner(error: error),
          ],

          const SizedBox(height: AppSpacing.lg),
          AppActionButton(
            label: selected == null ? '운행 시작' : '${selected.label} 운행 시작',
            tone: AppTone.primary,
            primaryAction: true,
            busy: state.isSubmitting,
            onPressed: selected == null || state.isSubmitting
                ? null
                : () => ref
                      .read(driveSessionControllerProvider.notifier)
                      .start(selected),
          ),
          if (selected == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '방향을 먼저 선택하세요',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 담당 버스 — 기사가 출발 전에 "내가 맞는 차에 탔는가"를 확인하는 카드.
///
/// 호차명·차량번호를 같이 보여주는 게 핵심이다. 학원에 같은 번호대의 차가 여러
/// 대 있어서 호차명만으로는 확신이 안 선다.
class _BusCard extends ConsumerWidget {
  const _BusCard({required this.busId});

  /// 세션이 알고 있는 담당 버스 id. `GET /api/buses/me` 가 실패해도 이건 남아
  /// 있어서 최소한 몇 호차인지는 보여줄 수 있다.
  final int? busId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `AsyncSection` 을 쓰지 않는다 — 그건 화면 전체를 에러 화면으로 바꾸는 위젯이라,
    // 버스 카드가 못 왔다고 아래 운행 시작 버튼까지 사라지면 기사가 출발을 못 한다.
    return ref
        .watch(myBusControllerProvider)
        .when(
          // 스켈레톤은 카드 테두리 없이 통짜로 둔다. 테두리까지 미리 그리면 로딩이
          // 끝나는 순간 안쪽만 바뀌어 화면이 두 번 움직인다.
          loading: () => const SkeletonBox(height: 128),
          // 실패해도 아는 것만 보여준다. 정원·배정 인원은 **비워 둔다** — 못 받은
          // 값을 그럴듯한 숫자로 채우면 기사가 남의 차 정보를 보고 출발한다.
          error: (_, _) =>
              _BusCardFrame(children: [_BusTitle(name: _fallbackName)]),
          data: (bus) => _BusCardFrame(
            children: bus == null
                ? [_BusTitle(name: _fallbackName)]
                : [
                    _BusTitle(name: bus.displayName, plate: bus.plateLabel),
                    const SizedBox(height: AppSpacing.md),
                    _BusStats(bus: bus),
                  ],
          ),
        );
  }

  String get _fallbackName => busId == null ? '배차 없음' : '$busId호차';
}

/// 버스 카드의 테두리·바탕. 로딩·실패·정상이 같은 틀 안에서 바뀌게 한다.
class _BusCardFrame extends StatelessWidget {
  const _BusCardFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        // 화면 위에 단독으로 놓이는 전폭 카드라 20 이다(§3.2).
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// 호차명 + 차량번호.
class _BusTitle extends StatelessWidget {
  const _BusTitle({required this.name, this.plate});

  final String name;
  final String? plate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plate = this.plate;

    // Row 가 아니라 Wrap 이다 — 글자 200% 확대에서 차량번호가 옆에 못 들어가면
    // 잘리는 대신 아랫줄로 내려가야 한다(§7-5).
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.smd,
      children: [
        Text(name, style: theme.textTheme.headlineSmall),
        if (plate != null)
          // 차량번호는 자릿수가 고정된 수치 표기라 mono 다(§2.1).
          Text(
            plate,
            style: AppTypography.mono(
              context,
            ).copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

/// 정원 · 배정 학생 · 노선.
class _BusStats extends StatelessWidget {
  const _BusStats({required this.bus});

  final MyBus bus;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.smd,
      children: [
        _BusStat(label: '정원', value: '${bus.seatCapacity}석'),
        // 시안은 `오늘 배정` 이지만 서버 값(`onboard`)은 **날짜와 무관한 배정 명부의
        // 크기**다. 오늘 결석 신고된 학생도 그 안에 들어 있어서 `오늘` 을 붙이면
        // 실제 명단 인원과 다른 숫자를 오늘의 사실처럼 읽게 된다.
        _BusStat(label: '배정 학생', value: '${bus.assignedCount}명'),
        // 노선이 없으면 칸을 비우지 않고 `없음` 이라고 쓴다 — 빈 칸은 "아직 안 온
        // 값"으로 읽혀서 기사가 새로고침만 반복한다.
        _BusStat(label: '노선', value: bus.routeLabel ?? '없음'),
      ],
    );
  }
}

class _BusStat extends StatelessWidget {
  const _BusStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption(context)),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

/// 등원/하원 중 하나. 카드 전체가 터치 영역이다.
class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    required this.direction,
    required this.isSelected,
    required this.onTap,
  });

  final DriveDirection direction;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = isSelected ? scheme.primary : scheme.surface;
    final foreground = isSelected ? scheme.onPrimary : scheme.onSurface;
    final subdued = isSelected ? scheme.onPrimary : scheme.onSurfaceVariant;
    final radius = BorderRadius.circular(AppSpacing.radiusLg);

    return Material(
      color: background,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTouch.primary),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isSelected ? scheme.primary : scheme.outlineVariant,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 선택 여부를 색만으로 알리지 않는다(§0-1) — 직사광선·색각 이상 대응.
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 24,
                color: foreground,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                direction.label,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                direction == DriveDirection.pickup ? '정류장 → 학원' : '학원 → 하차지',
                style: theme.textTheme.bodySmall?.copyWith(color: subdued),
              ),
              const SizedBox(height: AppSpacing.xs),
              // 서버에 보내는 값. 데모·QA 에서 방향이 맞게 갔는지 눈으로 대조한다.
              Text(
                direction.wireName,
                style: AppTypography.mono(context).copyWith(color: subdued),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 시작이 **선택 기능이 아니라 관문**임을 미리 알린다.
///
/// 이 문구가 없으면 기사는 명단 탭이 비어 있는 걸 고장으로 읽고 새로고침만 반복한다.
class _GateNotice extends StatelessWidget {
  const _GateNotice();

  @override
  Widget build(BuildContext context) {
    final foreground = AppTone.primary.onContainer(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: AppTone.primary.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '운행을 시작하면 학생 명단을 받아옵니다. 시작 전에는 명단을 볼 수 없습니다.',
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

/// 방금 끝낸 운행 요약(시안 06절). 종료하면 이 화면으로 돌아오므로 확인용으로 남긴다.
///
/// 톤은 `success` 다 — 완료·종료 요약은 성공 계열이라고 정해져 있다(§1.3).
///
/// ⚠️ **시안의 `거리` 칸은 넣지 않았다.** 시안이 쓴 값은 노선 계획의
/// `totalDistance`·`totalDurationS` 인데, 그건 실제로 얼마나 달렸는지가 아니라
/// **매일 똑같이 나오는 계획값**이다. 계획 거리라도 보여주려면 `features/routing`
/// 을 참조해야 하는데 그건 feature 간 의존이라(컨벤션 C-1) 여기서 열지 않는다.
/// 두 칸만 보여주는 편이 틀린 숫자를 세 칸 채우는 것보다 낫다.
class _LastRunSummary extends StatelessWidget {
  const _LastRunSummary({required this.session});

  final DriveSession session;

  @override
  Widget build(BuildContext context) {
    final endedAt = session.endedAt;
    final elapsed = session.elapsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EndedBanner(session: session),
        // 종료 시각이 없으면 지표를 만들 근거가 없다 — 구간이 안 정해지면
        // 소요 시간도 처리 건수도 계산할 수 없다.
        if (endedAt != null && elapsed != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _LastRunStats(session: session, endedAt: endedAt, elapsed: elapsed),
        ],
      ],
    );
  }
}

/// `✓ 하원 운행을 종료했습니다` + 종료 시각.
class _EndedBanner extends StatelessWidget {
  const _EndedBanner({required this.session});

  final DriveSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = AppTone.success.onContainer(context);
    final endedAt = session.endedAt;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTone.success.container(context),
        // 화면 위에 단독으로 놓이는 전폭 카드라 20 이다(§3.2).
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "끝났다"를 색만으로 알리지 않는다(§0-1). 아이콘·글자를 같이 둔다.
          Icon(Icons.task_alt, size: 20, color: foreground),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${session.direction.label} 운행을 종료했습니다',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foreground,
                  ),
                ),
                if (endedAt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${_formatDate(endedAt)} ${_formatTime(endedAt)} 종료',
                    style: AppTypography.mono(
                      context,
                    ).copyWith(color: foreground),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 소요 시간 · 처리 건수 두 칸.
class _LastRunStats extends ConsumerWidget {
  const _LastRunStats({
    required this.session,
    required this.endedAt,
    required this.elapsed,
  });

  final DriveSession session;
  final DateTime endedAt;

  /// `startedAt ~ endedAt` **실적**이다. 노선 계획의 예상 소요와 다르다.
  final Duration elapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final processed = ref.watch(
      lastRunProcessedCountProvider((
        busId: session.busId,
        serviceDate: session.serviceDate,
        startedAt: session.startedAt,
        endedAt: endedAt,
      )),
    );

    // 두 칸 높이를 맞춘다 — 한쪽이 스켈레톤이고 다른 쪽이 글자면 높이가 달라져
    // 값이 도착하는 순간 카드가 튄다.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              label: '소요 시간',
              child: Text(
                _formatElapsed(elapsed),
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatTile(
              label: '처리 건수',
              child: processed.when(
                loading: () => const SkeletonBox(height: 22, width: 48),
                // 못 세었으면 숫자를 짓지 않는다 — `0건` 과 "모른다"는 완전히 다른
                // 뜻이고, 기사는 0건을 "아무도 안 탔다"로 읽는다.
                error: (_, _) => Text(
                  '확인 불가',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                data: (count) =>
                    Text('$count건', style: theme.textTheme.titleMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        // 요약 카드에 딸린 작은 칸이라 행 반경(12)을 쓴다 — 위 배너(20)와 같은
        // 모서리면 둘이 같은 위계로 읽힌다(§3.2).
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.caption(context)),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

/// 실제 운행 시간 표기(시안 `6분 40초`).
///
/// 한 시간을 넘기면 초를 버린다 — `1시간 12분 07초` 는 한눈에 안 읽힌다.
String _formatElapsed(Duration elapsed) {
  if (elapsed.inHours > 0) {
    return '${elapsed.inHours}시간 ${elapsed.inMinutes % 60}분';
  }
  if (elapsed.inMinutes > 0) {
    return '${elapsed.inMinutes}분 ${elapsed.inSeconds % 60}초';
  }
  return '${elapsed.inSeconds}초';
}

/// 시안 표기(`2026. 7. 28.`). `intl` 패키지를 들이지 않으려고 직접 조립한다.
String _formatDate(DateTime time) =>
    '${time.year}. ${time.month}. ${time.day}.';

String _formatTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
