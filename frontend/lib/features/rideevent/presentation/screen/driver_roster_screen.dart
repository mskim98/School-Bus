import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/error_message.dart';
import '../../../drivesession/application/drive_session_controller.dart';
import '../../application/driver_roster_controller.dart';
import '../widget/drive_start_view.dart';
import '../widget/end_drive_sheet.dart';
import '../widget/roster_student_tile.dart';

/// 기사의 승하차 기록 화면 — **하루 중 가장 오래 머무는 화면**.
///
/// 운행 세션 유무에 따라 두 얼굴을 가진다:
///  - 운행 전 → 방향을 고르고 시작하는 [DriveStartView]
///  - 운행 중 → 학생별 승차/하차/인계 기록 명단
///
/// 화면을 둘로 나누지 않은 이유: 기사에게는 "운행"이라는 한 가지 일이고, 라우팅으로
/// 갈라두면 앱을 껐다 켰을 때 어느 화면으로 보내야 하는지를 두 곳에서 판단하게 된다.
class DriverRosterScreen extends ConsumerWidget {
  const DriverRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(driveSessionControllerProvider);

    return sessionState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Centered(
        child: ErrorBanner(
          error: error,
          onRetry: () =>
              ref.read(driveSessionControllerProvider.notifier).refresh(),
        ),
      ),
      data: (state) {
        if (!state.hasBus) {
          return const _EmptyState(
            icon: Icons.no_transfer_outlined,
            title: '배차된 버스가 없습니다',
            description: '관리자가 버스를 배정하면 운행을 시작할 수 있습니다.',
          );
        }
        if (!state.isDriving) return DriveStartView(state: state);
        return const _RosterView();
      },
    );
  }
}

/// 운행 중 명단.
class _RosterView extends ConsumerWidget {
  const _RosterView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rosterAsync = ref.watch(driverRosterControllerProvider);

    return Column(
      children: [
        Expanded(
          child: rosterAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _Centered(
              child: ErrorBanner(
                error: error,
                onRetry: () =>
                    ref.read(driveSessionControllerProvider.notifier).refresh(),
              ),
            ),
            data: (state) => _RosterList(state: state),
          ),
        ),
        const _EndDriveBar(),
      ],
    );
  }
}

class _RosterList extends ConsumerWidget {
  const _RosterList({required this.state});

  final DriverRosterState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = state.direction;
    if (state.students.isEmpty || direction == null) {
      return const _EmptyState(
        icon: Icons.groups_outlined,
        title: '오늘 태울 학생이 없습니다',
        description: '결석 신고된 학생은 명단에서 자동으로 빠집니다.',
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(driveSessionControllerProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _ProgressHeader(state: state),
          if (state.recordError case final error?) ...[
            const SizedBox(height: AppSpacing.md),
            ErrorBanner(
              error: error,
              onRetry: () => ref
                  .read(driverRosterControllerProvider.notifier)
                  .clearRecordError(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final student in state.students) ...[
            RosterStudentTile(
              student: student,
              direction: direction,
              isPending: state.isPending(student.studentId),
              onAction: (type) => ref
                  .read(driverRosterControllerProvider.notifier)
                  .record(student.studentId, type),
            ),
            // 오탭 방지 — 버튼끼리 충분히 떨어뜨린다.
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// 진행률 — "지금 몇 명 태우고 있고 몇 명 남았는지"를 1초 안에 읽히게.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.state});

  final DriverRosterState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = state.students.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          _Metric(
            label: state.direction?.label ?? '운행',
            value: '진행 중',
            icon: Icons.directions_bus_filled,
          ),
          _Metric(
            label: '탑승 중',
            value: '${state.onboard.length}명',
            icon: Icons.airline_seat_recline_normal,
          ),
          _Metric(
            label: '처리 완료',
            value: '${state.doneCount}/$total명',
            icon: Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: theme.hintColor),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }
}

/// 화면 하단 고정 — 운행 종료 진입.
///
/// 잔류 인원을 여기서 미리 보여준다. 시트를 열어야만 알 수 있으면 기사가 종료
/// 시점에 가서야 "아직 안 내렸네"를 알게 된다.
class _EndDriveBar extends ConsumerWidget {
  const _EndDriveBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onboardCount =
        ref.watch(driverRosterControllerProvider).value?.onboard.length ?? 0;
    final blocked = onboardCount > 0;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (blocked) ...[
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '$onboardCount명이 아직 차에 있습니다 — 하차 기록 후 종료할 수 있습니다',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              OutlinedButton.icon(
                onPressed: () => EndDriveSheet.show(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('운행 종료'),
              ),
            ],
          ),
        ),
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
