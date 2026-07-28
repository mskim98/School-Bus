import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/error_message.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../drivesession/application/drive_session_controller.dart';
import '../../application/driver_roster_controller.dart';

/// 운행 종료 확인 시트. **안전 기능이다.**
///
/// 차내에 아이가 남은 채 운행이 끝나는 사고를 막는 마지막 관문이라, 앱에서
/// **확인 단계를 두는 유일한 화면**이다(다른 동작은 탭 1회로 끝낸다).
///
/// 막는 층이 둘이다:
///  1. 화면 — 아직 하차하지 않은 학생이 있으면 종료 버튼 자체를 잠그고 이름을 보여준다
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
    final onboard = rosterAsync.value?.onboard ?? const [];

    // 명단을 아직 못 읽었으면 "잔류 0명"이라고 단정하지 않는다.
    final isRosterReady = rosterAsync.hasValue;
    final canEnd =
        isRosterReady &&
        onboard.isEmpty &&
        !(sessionState?.isSubmitting ?? false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('운행 종료', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),

            if (!isRosterReady)
              // 명단을 읽는 동안 종료 버튼이 잠긴다 — 왜 못 누르는지 문구로 알린다.
              const LoadingView(label: '탑승 명단을 확인하는 중')
            else if (onboard.isEmpty)
              _ClearBanner(theme: theme)
            else
              _BlockedBanner(names: [for (final s in onboard) s.name]),

            if (sessionState?.actionError case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              ErrorBanner(error: error),
            ],

            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: canEnd
                  ? () =>
                        ref.read(driveSessionControllerProvider.notifier).end()
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: (sessionState?.isSubmitting ?? false)
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.stop_circle_outlined),
              label: Text(
                (sessionState?.isSubmitting ?? false) ? '종료하는 중…' : '운행 종료',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('계속 운행'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 전원 하차 완료 — 종료해도 되는 상태.
class _ClearBanner extends StatelessWidget {
  const _ClearBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '탑승 학생 0명 · 전원 하차 완료',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 잔류 학생이 있어 종료할 수 없는 상태 — 누가 남았는지 이름으로 보여준다.
class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '차내에 ${names.length}명이 남아 있습니다',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '하차를 기록하지 않으면 운행을 종료할 수 없습니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final name in names)
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: Text(name),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
