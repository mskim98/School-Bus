import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// 의미 톤.
///
/// 디자인 시스템은 색을 **값이 아니라 역할**로 부른다(`docs/DESIGN_SYSTEM.md` §1).
/// 위젯이 `colorScheme.primaryContainer` 냐 `appColors.successContainer` 냐를
/// 매번 고르면 같은 의미가 화면마다 다른 색으로 새기 때문에, 의미 하나를
/// 골라 쓰게 여기서 한 번에 묶는다.
///
/// M3 `ColorScheme` 과 [AppColors] 가 반씩 나눠 갖고 있는 걸 합치는 자리이기도 하다
/// — success·warning 은 M3 에 없다.
enum AppTone {
  /// 대기·비활성·읽은 알림
  neutral,

  /// 승차·다음 정차·근접 알림
  primary,

  /// 하차
  warning,

  /// 인계 완료
  success,

  /// 전송 실패·미승차·종료 차단
  error,
}

/// [AppColors] 는 **필요한 톤에서만** 읽는다.
///
/// `switch` 밖에서 미리 꺼내면 `AppTone.error` 하나 쓰는 위젯까지
/// `ThemeExtension` 등록 여부에 묶인다 — M3 기본 테마만 얹은 위젯 테스트가
/// 색과 무관한 이유로 죽는다. warning·success 만 확장에서 온다.
extension AppToneColors on AppTone {
  /// 칩·배지·배너처럼 **넓은 면**에 쓰는 배경.
  Color container(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (this) {
      AppTone.neutral => scheme.surfaceContainerHigh,
      AppTone.primary => scheme.primaryContainer,
      AppTone.error => scheme.errorContainer,
      AppTone.warning => context.appColors.warningContainer,
      AppTone.success => context.appColors.successContainer,
    };
  }

  /// [container] 위의 글자·아이콘.
  Color onContainer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (this) {
      AppTone.neutral => scheme.onSurfaceVariant,
      AppTone.primary => scheme.onPrimaryContainer,
      AppTone.error => scheme.onErrorContainer,
      AppTone.warning => context.appColors.onWarningContainer,
      AppTone.success => context.appColors.onSuccessContainer,
    };
  }

  /// 버튼·마커처럼 **강조가 필요한 면**에 쓰는 진한 색.
  Color solid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (this) {
      AppTone.neutral => scheme.outline,
      AppTone.primary => scheme.primary,
      AppTone.error => scheme.error,
      AppTone.warning => context.appColors.warning,
      AppTone.success => context.appColors.success,
    };
  }

  /// [solid] 위의 글자·아이콘.
  Color onSolid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (this) {
      AppTone.neutral => scheme.surface,
      AppTone.primary => scheme.onPrimary,
      AppTone.error => scheme.onError,
      AppTone.warning => context.appColors.onWarning,
      AppTone.success => context.appColors.onSuccess,
    };
  }
}
