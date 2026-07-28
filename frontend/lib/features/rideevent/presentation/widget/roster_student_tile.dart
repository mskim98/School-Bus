import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../drivesession/domain/drive_session.dart';
import '../../domain/ride_event.dart';
import '../../domain/roster_student.dart';

/// 명단의 한 줄 — 이름 · 장소 · 현재 단계 · **다음 동작 버튼 하나**.
///
/// 운전석에서 정차 30초 안에 쓰는 화면이라 규칙이 세 가지다:
///  1. 버튼은 **한 줄에 하나만** — 학생 1명 처리에 탭 1회, 고를 게 없으니 오탭도 없다
///  2. 전송이 끝나기 전에는 단계를 바꾸지 않는다 — 실패했는데 완료로 보이면 안 된다
///  3. 상태는 **색만으로 구분하지 않는다** — 직사광선 아래서도 아이콘·글자로 읽힌다
class RosterStudentTile extends StatelessWidget {
  const RosterStudentTile({
    super.key,
    required this.student,
    required this.direction,
    required this.isPending,
    required this.onAction,
  });

  final RosterStudent student;

  /// 등원/하원. 하원에서만 인계(HANDOVER) 단계가 나온다.
  final DriveDirection direction;

  /// 이 학생의 기록을 서버로 보내는 중.
  final bool isPending;

  final ValueChanged<RideEventType> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = student.nextActionFor(direction);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (student.location != null) ...[
                  const SizedBox(height: AppSpacing.xs / 2),
                  Text(
                    student.location!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _StatusLabel(student: student),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _ActionArea(next: next, isPending: isPending, onAction: onAction),
        ],
      ),
    );
  }
}

/// 현재 단계 — 아이콘 + 글자 + (있으면) 기록 시각.
class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.student});

  final RosterStudent student;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onboard = student.isOnboard;
    final color = onboard
        ? theme.colorScheme.primary
        : student.status == RideStatus.waiting
        ? theme.hintColor
        : theme.colorScheme.onSurface;

    return Row(
      children: [
        Icon(_iconOf(student.status), size: 18, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          student.status.label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (student.updatedAt case final at?) ...[
          const SizedBox(width: AppSpacing.sm),
          // 기사가 "방금 눌렀나"를 눈으로 확인하는 근거. 초까지 볼 이유는 없다.
          Text(
            _hhmm(at),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.hintColor,
            ),
          ),
        ],
      ],
    );
  }

  static IconData _iconOf(RideStatus status) => switch (status) {
    RideStatus.waiting => Icons.schedule_outlined,
    RideStatus.boarded => Icons.directions_bus_filled,
    RideStatus.alighted => Icons.exit_to_app,
    RideStatus.handedOver => Icons.verified_outlined,
  };

  static String _hhmm(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// 다음 동작 버튼, 전송 중 표시, 또는 완료 표시.
class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.next,
    required this.isPending,
    required this.onAction,
  });

  final RideEventType? next;
  final bool isPending;
  final ValueChanged<RideEventType> onAction;

  /// 흔들리는 차 안에서 장갑 낀 손으로 누른다 — 48dp 최소 규격보다 넉넉히 잡는다.
  static const Size _minTouchTarget = Size(112, 56);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isPending) {
      return SizedBox(
        width: _minTouchTarget.width,
        height: _minTouchTarget.height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('전송 중', style: theme.textTheme.labelMedium),
          ],
        ),
      );
    }

    final action = next;
    if (action == null) {
      return SizedBox(
        width: _minTouchTarget.width,
        height: _minTouchTarget.height,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '완료',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return FilledButton(
      onPressed: () => onAction(action),
      style: FilledButton.styleFrom(
        minimumSize: _minTouchTarget,
        textStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(action.label),
    );
  }
}
