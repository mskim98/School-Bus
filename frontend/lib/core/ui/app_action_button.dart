import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import 'app_tone.dart';

/// 기록·확정용 액션 버튼.
///
/// 왜 `FilledButton` 을 그대로 쓰지 않는가:
///  - 승하차 기록은 **의미 톤**(승차=primary, 인계=success, 재시도=error)을 따르는데
///    M3 버튼은 primary/error 밖에 모른다. success 는 [AppColors] 쪽에 있다
///  - 정차 시간이 30초 남짓이라 **탭 1회**로 끝나야 하고, 그래서 크기·간격이
///    화면마다 흔들리면 안 된다(`docs/DESIGN_SYSTEM.md` §3.3)
///
/// [busy] 는 **전송 중**을 뜻한다. 이때 버튼은 눌리지 않는다 — 학부모 알림이
/// 걸린 기록이라 중복 전송이 곧 사고다.
class AppActionButton extends StatelessWidget {
  const AppActionButton({
    super.key,
    required this.label,
    required this.tone,
    required this.onPressed,
    this.icon,
    this.outlined = false,
    this.primaryAction = false,
    this.busy = false,
  });

  /// 아이콘 문자(`↑` `↓` `✓`). 상태 계약(§4)이 정한 문자를 그대로 쓴다.
  final String? icon;
  final String label;
  final AppTone tone;
  final VoidCallback? onPressed;

  /// 테두리만 있는 형태 — `다시 시도`처럼 주 동작이 아닐 때.
  final bool outlined;

  /// 화면당 하나뿐인 주요 동작(운행 시작·운행 종료). 높이가 56 이 된다.
  final bool primaryAction;

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final height = primaryAction ? AppTouch.primary : AppTouch.min;
    final foreground = outlined ? tone.solid(context) : tone.onSolid(context);

    final child = busy
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Text(icon == null ? label : '$icon $label');

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    );

    if (outlined) {
      return OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: Size.fromHeight(height),
          foregroundColor: foreground,
          side: BorderSide(color: tone.solid(context)),
          shape: shape,
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        backgroundColor: tone.solid(context),
        foregroundColor: foreground,
        shape: shape,
      ),
      child: child,
    );
  }
}

/// 기록이 **서버에 저장돼 확정된** 뒤 액션 버튼 자리에 남는 표시.
///
/// [AppActionButton] 과 같은 파일에 둔 건 **같은 자리의 두 상태**이기 때문이다.
/// 비활성 버튼(회색)으로 그리지 않는 이유: 회색은 "지금은 못 누른다"로 읽히지만
/// 여기서 전할 뜻은 "**끝났다**"다. 애초에 버튼이 아니라 표시라서 눌리지 않는다.
class AppActionDone extends StatelessWidget {
  const AppActionDone({super.key, this.label = '완료', this.icon = '✓'});

  final String label;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppTouch.min,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTone.success.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Text(
        '$icon $label',
        // 액션 버튼과 같은 자리에 교대로 놓이므로 같은 슬롯(labelLarge)을 쓴다.
        // 크기가 1px 만 달라도 기록이 확정되는 순간 그 자리가 미세하게 흔들린다.
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppTone.success.onContainer(context),
        ),
      ),
    );
  }
}
