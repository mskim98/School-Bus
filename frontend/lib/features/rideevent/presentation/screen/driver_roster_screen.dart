import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/app_action_button.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/async_section.dart';
import '../../../../core/ui/empty_view.dart';
import '../../../../core/ui/error_message.dart';
import '../../../../core/ui/skeleton_box.dart';
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

    return AsyncSection(
      value: sessionState,
      onRetry: () =>
          ref.read(driveSessionControllerProvider.notifier).refresh(),
      data: (state) {
        if (!state.hasBus) {
          return const EmptyView(
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
          child: AsyncSection(
            value: rosterAsync,
            onRetry: () =>
                ref.read(driveSessionControllerProvider.notifier).refresh(),
            loadingLabel: '명단을 불러오는 중',
            // 스피너 대신 스켈레톤 — 곧 무엇이 어디 나타날지 미리 보여줘야
            // 명단이 뜬 뒤에 눈이 화면을 다시 훑지 않는다(§6).
            loading: () =>
                const SkeletonList(header: 76, itemCount: 3, itemHeight: 96),
            data: (state) => _RosterList(state: state),
          ),
        ),
        const _EndDriveBar(),
      ],
    );
  }
}

class _RosterList extends ConsumerStatefulWidget {
  const _RosterList({required this.state});

  final DriverRosterState state;

  @override
  ConsumerState<_RosterList> createState() => _RosterListState();
}

class _RosterListState extends ConsumerState<_RosterList> {
  /// 직전 전송이 실패한 학생.
  ///
  /// 컨트롤러의 [DriverRosterState.recordError] 는 **누구의 실패인지**를 담지 않아
  /// (화면 상단 배너용 단일 필드) 행 단위 표시를 만들 수 없다. 그래서 전송이
  /// 끝나는 순간(`pending` 에서 빠지는 순간)과 에러가 채워지는 순간을 맞춰
  /// 여기서 추린다. 추측이 아니다 — 컨트롤러가 학생 한 명씩 상태를 갱신하므로
  /// 매 전이마다 방금 끝난 학생은 정확히 한 명이다.
  ///
  /// 이 화면 안에서만 사는 표시용 상태다. 컨트롤러가 실패에 `studentId` 를
  /// 싣게 되면 이 계산은 통째로 사라진다.
  Set<int> _failed = const {};

  @override
  Widget build(BuildContext context) {
    ref.listen(driverRosterControllerProvider, _trackFailures);

    final state = widget.state;
    final direction = state.direction;
    if (state.students.isEmpty || direction == null) {
      return const EmptyView(
        icon: Icons.groups_outlined,
        title: '오늘 태울 학생이 없습니다',
        description: '결석 신고된 학생은 명단에서 자동으로 빠집니다. 태울 학생이 없으면 바로 운행을 종료해도 됩니다.',
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
              hasFailed: _failed.contains(student.studentId),
              onAction: (type) => ref
                  .read(driverRosterControllerProvider.notifier)
                  .record(student.studentId, type),
            ),
            // 오탭 방지 — 버튼끼리 충분히 떨어뜨린다(§3.3).
            const SizedBox(height: AppSpacing.md),
          ],
          const _RecordNotice(),
        ],
      ),
    );
  }

  void _trackFailures(
    AsyncValue<DriverRosterState>? previous,
    AsyncValue<DriverRosterState> next,
  ) {
    final before = previous?.value;
    final after = next.value;
    if (before == null || after == null) return;

    // 다시 누른 학생은 실패 표시를 즉시 지운다 — 재시도 중에도 빨간 테두리가
    // 남아 있으면 방금 누른 것이 또 실패한 것처럼 보인다.
    final started = after.pending.difference(before.pending);
    final justFinished = before.pending.difference(after.pending);
    final failedNow = before.recordError == null && after.recordError != null
        ? justFinished
        : const <int>{};

    final updated = _failed.difference(started).union(failedNow);
    if (!setEquals(updated, _failed)) {
      setState(() => _failed = updated);
    }
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
    final done = state.doneCount;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('현재 탑승', style: AppTypography.caption(context)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${state.onboard.length}명',
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 1,
            height: AppSpacing.xl,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${state.direction?.label ?? '운행'} · 처리 $done/$total명',
                  style: AppTypography.caption(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : done / total,
                    minHeight: AppSpacing.sm,
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    color: theme.colorScheme.primary,
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

/// 명단 아래 안내 — 이 화면이 왜 느리게 확정되는지를 미리 알려 둔다.
///
/// 없으면 기사는 `전송 중` 을 앱이 굼뜬 것으로 읽고 버튼을 연타한다.
class _RecordNotice extends StatelessWidget {
  const _RecordNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '기록 즉시 학부모에게 알림이 발송됩니다. 서버 저장이 확인된 뒤에 상태가 확정 표시됩니다.',
              style: AppTypography.caption(context),
            ),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (blocked) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '$onboardCount명이 아직 차에 있습니다 — 하차를 기록해야 종료할 수 있습니다',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              AppActionButton(
                label: '운행 종료',
                tone: AppTone.primary,
                primaryAction: true,
                onPressed: () => EndDriveSheet.show(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
