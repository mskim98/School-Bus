import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/app_action_button.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/error_message.dart';
import '../../../drivesession/application/drive_session_controller.dart';
import '../../../drivesession/domain/drive_session.dart';

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

/// 담당 버스.
///
/// ⚠️ 지금은 버스 **id** 밖에 못 보여준다. 시안이 요구하는 호차명·차량번호·정원·
/// 오늘 배정 인원은 `GET /api/buses/me` 응답에 있지만, 앱에서 그 응답을 통째로
/// 들고 있는 곳이 없다(`auth` 가 busId 만 뽑아 세션에 얹는다). 채우려면 bus
/// feature 의 repository 가 필요하다 — 화면 이식 범위 밖이라 남겨 둔다.
/// 없는 값을 그럴듯한 자리표시자로 채우지 않는 게 낫다(기사가 남의 차를 탄다).
class _BusCard extends StatelessWidget {
  const _BusCard({required this.busId});

  final int? busId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busId = this.busId;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_bus_filled,
            size: 28,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '담당 버스',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  busId == null ? '배차 없음' : '$busId호차',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ],
      ),
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

/// 방금 끝낸 운행 요약. 종료 직후 이 화면으로 돌아오므로 확인용으로 남긴다.
///
/// 톤은 `success` 다 — 완료·종료 요약은 성공 계열이라고 정해져 있다(§1.3).
class _LastRunSummary extends StatelessWidget {
  const _LastRunSummary({required this.session});

  final DriveSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = session.elapsed;
    final foreground = AppTone.success.onContainer(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: AppTone.success.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.task_alt, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              elapsed == null
                  ? '${session.direction.label} 운행을 종료했습니다'
                  : '${session.direction.label} 운행 종료 · ${elapsed.inMinutes}분 운행',
              style: theme.textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
