import 'package:flutter/material.dart';

/// M3 `ColorScheme` 에 없는 역할색.
///
/// 디자인 시스템(`docs/DESIGN_SYSTEM.md` §1.3)은 역할색 12종 외에
/// **성공·경고·지도** 3계열을 더 쓰는데, Material 3 의 `ColorScheme` 에는
/// 이 셋이 없다(M3 는 primary/secondary/tertiary/error 만 정의한다).
///
/// 그래서 `ThemeExtension` 으로 붙인다 — 화면에서 hex 를 직접 쓰지 않고
/// 라이트/다크가 자동 전환되게 하려면 테마에 태워야 하기 때문이다.
///
/// 읽는 법:
/// ```dart
/// final c = context.appColors;
/// Container(color: c.successContainer);
/// ```
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.mapBase,
    required this.mapLine,
  });

  /// 인계완료 동작 버튼.
  final Color success;
  final Color onSuccess;

  /// 인계 칩 · 완료 표시 · 운행 종료 요약.
  final Color successContainer;
  final Color onSuccessContainer;

  /// 주의 표시(테스트 모드 등).
  final Color warning;
  final Color onWarning;

  /// 하차 칩 · 하차 태그.
  final Color warningContainer;
  final Color onWarningContainer;

  /// 지도 배경(타일 톤). **표면색과 절대 공유하지 않는다** —
  /// 지도가 카드처럼 보이면 "여기가 지도"라는 인지가 깨진다.
  final Color mapBase;

  /// 지도 도로망 선.
  final Color mapLine;

  static const AppColors light = AppColors(
    success: Color(0xFF186B3B),
    onSuccess: Color(0xFFFAF9FD), // = surface
    successContainer: Color(0xFFB8F1C7),
    onSuccessContainer: Color(0xFF00210F),
    warning: Color(0xFF7A5900),
    onWarning: Color(0xFFFAF9FD), // = surface
    warningContainer: Color(0xFFFFE1A3),
    onWarningContainer: Color(0xFF2B1D00),
    mapBase: Color(0xFFE7EBE3),
    mapLine: Color(0xFFCFD6C8),
  );

  static const AppColors dark = AppColors(
    success: Color(0xFF7FDB9C),
    onSuccess: Color(0xFF111318), // = surface
    successContainer: Color(0xFF17512C),
    onSuccessContainer: Color(0xFFB8F1C7),
    warning: Color(0xFFF2C14E),
    onWarning: Color(0xFF111318), // = surface
    warningContainer: Color(0xFF4A3600),
    onWarningContainer: Color(0xFFFFDF9E),
    mapBase: Color(0xFF22262B),
    mapLine: Color(0xFF343A40),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? mapBase,
    Color? mapLine,
  }) {
    return AppColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      mapBase: mapBase ?? this.mapBase,
      mapLine: mapLine ?? this.mapLine,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      mapBase: Color.lerp(mapBase, other.mapBase, t)!,
      mapLine: Color.lerp(mapLine, other.mapLine, t)!,
    );
  }
}

/// `Theme.of(context).extension<AppColors>()!` 를 매번 쓰지 않기 위한 축약.
///
/// `!` 를 여기 한 곳에만 두는 것도 목적이다 — 테마 등록을 빠뜨리면
/// 화면 곳곳이 아니라 이 한 줄에서 터진다.
extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
