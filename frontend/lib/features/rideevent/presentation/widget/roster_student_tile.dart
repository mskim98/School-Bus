import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/app_action_button.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../drivesession/domain/drive_session.dart';
import '../../domain/ride_event.dart';
import '../../domain/roster_student.dart';
import 'ride_status_chip.dart';

/// 명단의 한 줄 — 이니셜 · 이름 · 장소 · 현재 단계 · **다음 동작 버튼 하나**.
///
/// 운전석에서 정차 30초 안에 쓰는 화면이라 규칙이 네 가지다:
///  1. 버튼은 **한 줄에 하나만** — 학생 1명 처리에 탭 1회, 고를 게 없으니 오탭도 없다
///  2. 전송이 끝나기 전에는 단계를 바꾸지 않는다 — 실패했는데 완료로 보이면 안 된다(§0-2)
///  3. 상태는 **색만으로 구분하지 않는다** — 아이콘·글자를 항상 같이 낸다([RideStatusChip])
///  4. 학생 사진은 없다 — **이니셜 원형 44dp 까지가 한계**다(§8). API 에 사진이 없다
class RosterStudentTile extends StatelessWidget {
  const RosterStudentTile({
    super.key,
    required this.student,
    required this.direction,
    required this.isPending,
    required this.onAction,
    this.hasFailed = false,
    this.isNoShow = false,
  });

  /// 액션 열 폭. 고정해야 학생이 3명이든 25명이든 버튼이 세로로 줄을 맞춘다 —
  /// 줄마다 버튼 위치가 흔들리면 흔들리는 차 안에서 조준이 안 된다(§5.2).
  static const double _actionColumn = 112;

  /// 이 폭을 넘어가면 버튼 글자가 [_actionColumn] 안에 한 줄로 안 들어간다.
  /// 그때는 행을 세로로 접는다 — 잘린 버튼보다 두 줄짜리 행이 낫다(§7-5).
  static const double _stackAboveTextScale = 1.15;

  final RosterStudent student;

  /// 등원/하원. 하원에서만 인계(HANDOVER) 단계가 나온다.
  final DriveDirection direction;

  /// 이 학생의 기록을 서버로 보내는 중.
  final bool isPending;

  /// 직전 전송이 실패했다 — 단계는 되돌아가 있고, 이 줄에 `다시 시도` 가 붙는다.
  final bool hasFailed;

  /// 도착 10분 뒤 서버가 발행하는 미승차 상태.
  ///
  /// ⚠️ 지금은 항상 `false` 다. 서버가 NO_SHOW 를 **알림으로만** 보내고
  /// 명단/승하차 응답에는 담지 않아서 화면이 알 방법이 없다. 표기 규칙(§4)은
  /// 여기 구현해 두고, 데이터가 생기면 이 인자만 채우면 된다.
  final bool isNoShow;

  final ValueChanged<RideEventType> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = student.nextActionFor(direction);
    final isDone = next == null && !isPending && !hasFailed;

    final stacked =
        MediaQuery.textScalerOf(context).scale(1) > _stackAboveTextScale;

    final action = _ActionArea(
      next: next,
      isPending: isPending,
      hasFailed: hasFailed,
      onAction: onAction,
    );
    final body = _Body(
      student: student,
      isPending: isPending,
      hasFailed: hasFailed,
      isNoShow: isNoShow,
    );
    final avatar = _Initial(name: student.name, isNoShow: isNoShow);

    return Opacity(
      // 처리가 끝난 줄은 한 단 물러난다. 회색으로 죽이지는 않는다 —
      // 기사가 나중에 "이 아이 처리했나"를 다시 확인하는 근거이기 때문이다.
      opacity: isDone ? 0.75 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          // 미승차는 칩 하나로는 부족하다 — 행 전체가 눈에 띄어야 한다(§5.2).
          color: isNoShow
              ? AppTone.error.container(context)
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isNoShow || hasFailed
                ? theme.colorScheme.error
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar,
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: body),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.smd),
                  action,
                ],
              )
            : Row(
                children: [
                  avatar,
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: body),
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: _actionColumn,
                    child: _CompactButtons(child: action),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 이니셜 원형. 사진 대신 쓰는 최소 표기(§8).
class _Initial extends StatelessWidget {
  const _Initial({required this.name, required this.isNoShow});

  static const double _size = 44;

  final String name;
  final bool isNoShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = isNoShow ? AppTone.error : AppTone.neutral;

    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.container(context),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? '?' : name.substring(0, 1),
        style: theme.textTheme.titleMedium?.copyWith(
          color: tone.onContainer(context),
        ),
      ),
    );
  }
}

/// 이름 · 장소 · 상태 줄.
///
/// 세 덩어리 모두 [Wrap] 인 게 핵심이다. 글자 확대 200% 에서 `Row` 로 두면
/// 이름이나 상태 칩이 잘린다(§7-5).
class _Body extends StatelessWidget {
  const _Body({
    required this.student,
    required this.isPending,
    required this.hasFailed,
    required this.isNoShow,
  });

  final RosterStudent student;
  final bool isPending;
  final bool hasFailed;
  final bool isNoShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryText = isNoShow
        ? AppTone.error.onContainer(context)
        : theme.colorScheme.onSurface;
    final subText = isNoShow
        ? AppTone.error.onContainer(context)
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              student.name,
              style: theme.textTheme.titleMedium?.copyWith(color: primaryText),
            ),
            if (isNoShow) const NoShowBadge(),
          ],
        ),
        if (student.location case final place?) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            place,
            style: theme.textTheme.bodySmall?.copyWith(color: subText),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            // 전송 중에도 칩은 **이전 상태 그대로**다(§4.2). 여기서 미리 새 상태를
            // 그리면 그게 곧 낙관적 UI 고, 실패했을 때 기사가 잘못 안심한다.
            RideStatusChip(status: student.status),
            if (isPending) const _SendingLabel(),
            if (hasFailed) const _FailedLabel(),
            if (!isPending && !hasFailed)
              // 기사가 "방금 눌렀나"를 눈으로 확인하는 근거. 초까지 볼 이유는 없다.
              if (student.updatedAt case final at?) _RecordedAt(time: at),
          ],
        ),
      ],
    );
  }
}

/// 전송 중 — 확정이 아니라는 표시.
class _SendingLabel extends StatelessWidget {
  const _SendingLabel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: color),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '전송 중',
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// 전송 실패 — 상태는 되돌아가 있고, 액션 열에 `다시 시도` 가 떠 있다.
class _FailedLabel extends StatelessWidget {
  const _FailedLabel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      '✕ 전송 실패',
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.error,
      ),
    );
  }
}

/// 마지막 기록 시각. 자릿수가 흔들리지 않게 mono 슬롯을 쓴다(§2.1).
class _RecordedAt extends StatelessWidget {
  const _RecordedAt({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return Text(
      '$hour:$minute',
      style: AppTypography.mono(
        context,
      ).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// 다음 동작 버튼, 전송 중(버튼 없음), 재시도, 또는 완료 표시.
class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.next,
    required this.isPending,
    required this.hasFailed,
    required this.onAction,
  });

  final RideEventType? next;
  final bool isPending;
  final bool hasFailed;
  final ValueChanged<RideEventType> onAction;

  @override
  Widget build(BuildContext context) {
    final action = next;

    // 전송 중에는 버튼이 사라진다(§4.2). 잠긴 버튼을 남겨두면 연타하게 되고,
    // 중복 전송은 학부모 알림이 두 번 가는 사고다.
    if (isPending) return const SizedBox.shrink();

    if (hasFailed && action != null) {
      return AppActionButton(
        label: '다시 시도',
        tone: AppTone.error,
        outlined: true,
        onPressed: () => onAction(action),
      );
    }

    // 회색 비활성 버튼으로 그리지 않는다 — 여기 뜻은 "못 누른다"가 아니라 "끝났다"다.
    if (action == null) return const AppActionDone();

    return AppActionButton(
      icon: action.icon,
      label: action.label,
      tone: action.tone,
      onPressed: () => onAction(action),
    );
  }
}

/// 112dp 액션 열 안에서 `✓ 인계완료` 가 한 줄로 들어가게 버튼 좌우 여백만 줄인다.
///
/// 시안도 이 자리 버튼만 `padding:0 10px` 를 쓴다(`통학버스 디자인 시스템.dc.html` 478줄).
/// 전역 테마를 건드리면 다른 화면 버튼까지 같이 좁아지므로 이 줄에서만 덮는다.
class _CompactButtons extends StatelessWidget {
  const _CompactButtons({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const padding = WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: AppSpacing.smd),
    );

    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: (theme.filledButtonTheme.style ?? const ButtonStyle())
              .copyWith(padding: padding),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: (theme.outlinedButtonTheme.style ?? const ButtonStyle())
              .copyWith(padding: padding),
        ),
      ),
      child: child,
    );
  }
}
