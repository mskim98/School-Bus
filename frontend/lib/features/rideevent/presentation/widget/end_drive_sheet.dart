import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_action_button.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/error_message.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../drivesession/application/drive_session_controller.dart';
import '../../application/driver_roster_controller.dart';
import '../../domain/roster_student.dart';
import 'ride_status_chip.dart';

/// 운행 종료 확인 시트. **안전 기능이다.**
///
/// 차내에 아이가 남은 채 운행이 끝나는 사고를 막는 마지막 관문이라, 앱에서
/// **확인 단계를 두는 유일한 화면**이다(다른 동작은 탭 1회로 끝낸다).
///
/// 막는 층이 둘이다:
///  1. 화면 — 아직 하차하지 않은 학생이 있으면 종료 버튼 자체를 내리고 이름을 보여준다
///  2. 서버 — 그래도 요청이 가면 409 로 거절한다. 그 문구를 그대로 띄운다
class EndDriveSheet extends ConsumerWidget {
  const EndDriveSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const EndDriveSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // 종료가 성공하면 진행 중 운행이 사라진다 — 그때 시트를 닫는다.
    ref.listen(activeDriveSessionProvider, (_, next) {
      if (next == null && context.mounted) Navigator.of(context).pop();
    });

    final sessionState = ref.watch(driveSessionControllerProvider).value;
    final rosterAsync = ref.watch(driverRosterControllerProvider);
    final onboard = rosterAsync.value?.onboard ?? const <RosterStudent>[];
    final isSubmitting = sessionState?.isSubmitting ?? false;

    // 명단을 아직 못 읽었으면 "잔류 0명"이라고 단정하지 않는다.
    final isRosterReady = rosterAsync.hasValue;
    final isBlocked = isRosterReady && onboard.isNotEmpty;
    final canEnd = isRosterReady && onboard.isEmpty && !isSubmitting;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('운행 종료', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.md),

              if (!isRosterReady)
                // 명단을 읽는 동안 종료 버튼이 잠긴다 — 왜 못 누르는지 문구로 알린다.
                const LoadingView(label: '탑승 명단을 확인하는 중')
              else if (isBlocked)
                _BlockedCard(onboard: onboard)
              else
                const _ClearCard(),

              if (sessionState?.actionError case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                ErrorBanner(error: error),
              ],

              const SizedBox(height: AppSpacing.lg),

              // 막힌 상태에서는 종료 버튼을 아예 내린다. 잠긴 버튼을 남겨 두면
              // 기사가 그걸 누르며 "왜 안 되지"를 반복하게 되는데, 지금 필요한
              // 행동은 종료가 아니라 **명단으로 돌아가 하차를 기록하는 것**이다.
              if (isBlocked)
                AppActionButton(
                  label: '명단으로 돌아가 하차 기록',
                  tone: AppTone.error,
                  primaryAction: true,
                  onPressed: () => Navigator.of(context).pop(),
                )
              else
                AppActionButton(
                  label: isSubmitting ? '종료하는 중…' : '운행 종료',
                  tone: AppTone.primary,
                  primaryAction: true,
                  busy: isSubmitting,
                  onPressed: canEnd
                      ? () => ref
                            .read(driveSessionControllerProvider.notifier)
                            .end()
                      : null,
                ),

              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppTouch.min),
                ),
                child: const Text('계속 운행'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 전원 하차 완료 — 종료해도 되는 상태.
class _ClearCard extends StatelessWidget {
  const _ClearCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = AppTone.success.onContainer(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTone.success.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Emblem(symbol: '✓', tone: AppTone.success),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Text(
                  '탑승 학생 0명',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          Text(
            '전원 하차 완료 · 지금 운행을 종료할 수 있습니다.',
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

/// 잔류 학생이 있어 종료할 수 없는 상태.
///
/// **누가 남았는지**를 이름·장소·상태까지 보여준다. 인원수만 알려주면 기사가
/// 명단을 처음부터 다시 훑어야 하고, 그 사이 아이가 차에 남는다.
class _BlockedCard extends StatelessWidget {
  const _BlockedCard({required this.onboard});

  final List<RosterStudent> onboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = AppTone.error.onContainer(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTone.error.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _Emblem(symbol: '!', tone: AppTone.error),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Text(
                  '종료할 수 없습니다',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          Text(
            '차내에 아직 하차하지 않은 학생이 ${onboard.length}명 있습니다. '
            '전원 하차를 기록해야 운행을 종료할 수 있습니다.',
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
          const SizedBox(height: AppSpacing.smd),
          for (final student in onboard) ...[
            _RemainingRow(student: student),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// 남은 학생 한 명 — 명단 행과 같은 정보 구조로 둔다.
///
/// 여기서 상태를 다시 그리지 않고 [RideStatusChip] 을 쓰는 게 중요하다.
/// 같은 상태를 두 화면이 다른 문구로 부르면 그게 사고다(§4).
class _RemainingRow extends StatelessWidget {
  const _RemainingRow({required this.student});

  static const double _initialSize = 36;

  final RosterStudent student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: _initialSize,
            height: _initialSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTone.primary.container(context),
              shape: BoxShape.circle,
            ),
            child: Text(
              student.name.isEmpty ? '?' : student.name.substring(0, 1),
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppTone.primary.onContainer(context),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(student.name, style: theme.textTheme.titleMedium),
                if (student.location case final place?) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    place,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          RideStatusChip(status: student.status),
        ],
      ),
    );
  }
}

/// 카드 머리의 원형 기호. 아이콘 폰트 대신 §4 표의 문자를 그대로 쓴다.
class _Emblem extends StatelessWidget {
  const _Emblem({required this.symbol, required this.tone});

  static const double _size = 40;

  final String symbol;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.solid(context),
        shape: BoxShape.circle,
      ),
      child: Text(
        symbol,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(color: tone.onSolid(context)),
      ),
    );
  }
}
