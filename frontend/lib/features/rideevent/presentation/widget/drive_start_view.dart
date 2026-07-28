import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/error_message.dart';
import '../../../drivesession/application/drive_session_controller.dart';
import '../../../drivesession/domain/drive_session.dart';

/// 운행 시작 화면 — 기사가 하루를 여는 곳.
///
/// 방향을 **명시적으로 고르게** 한다(기본 선택 없음). 등원/하원이 뒤바뀌면 명단의
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
    final canStart = _selected != null && !state.isSubmitting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BusCard(busId: state.busId),
          if (state.lastCompleted case final done?) ...[
            const SizedBox(height: AppSpacing.sm),
            _LastRunSummary(session: done),
          ],
          const SizedBox(height: AppSpacing.lg),

          Text('오늘 운행 방향', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final direction in DriveDirection.values) ...[
            _DirectionOption(
              direction: direction,
              isSelected: _selected == direction,
              onTap: state.isSubmitting
                  ? null
                  : () => setState(() => _selected = direction),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          if (state.actionError case final error?) ...[
            const SizedBox(height: AppSpacing.sm),
            ErrorBanner(error: error),
          ],

          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: canStart
                ? () => ref
                      .read(driveSessionControllerProvider.notifier)
                      .start(_selected!)
                : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(64),
              textStyle: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: state.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(state.isSubmitting ? '시작하는 중…' : '운행 시작'),
          ),
          if (_selected == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '방향을 먼저 선택하세요',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
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
/// ⚠️ 지금은 버스 **id** 밖에 못 보여준다. 호차명·차량번호·정원은
/// `GET /api/buses/me` 응답에 있지만, 앱에서 그 응답을 통째로 들고 있는 곳이 없다
/// (`auth` 가 busId 만 뽑아 세션에 얹는다). 버스 정보를 다 보여주려면 bus feature 의
/// repository 가 필요하다 — C7 범위 밖이라 남겨 둔다.
class _BusCard extends StatelessWidget {
  const _BusCard({required this.busId});

  final int? busId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            Icons.directions_bus_filled,
            size: 32,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '담당 버스',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  busId == null ? '배차 없음' : '$busId호차',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 등원/하원 중 하나. 한 손으로 누르기 쉽게 한 줄을 통째로 쓴다.
class _DirectionOption extends StatelessWidget {
  const _DirectionOption({
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

    return Material(
      color: isSelected
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // 선택 여부를 색만으로 알리지 않는다(직사광선).
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                direction.label,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                direction == DriveDirection.pickup ? '집 → 학원' : '학원 → 집',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 방금 끝낸 운행 요약. 종료 직후 이 화면으로 돌아오므로 확인용으로 남긴다.
class _LastRunSummary extends StatelessWidget {
  const _LastRunSummary({required this.session});

  final DriveSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final elapsed = session.elapsed;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(Icons.task_alt, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              elapsed == null
                  ? '${session.direction.label} 운행을 종료했습니다'
                  : '${session.direction.label} 운행 종료 · ${elapsed.inMinutes}분 운행',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
