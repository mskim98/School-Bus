import 'package:flutter/material.dart';

import 'app_spacing.dart';

/// 앱 테마 단일 정의.
///
/// 색·타이포를 화면에서 직접 만들지 않는다 — 여기서만 정의하고 화면은
/// `Theme.of(context)` 로 읽는다(컨벤션 §8). 다크 테마나 브랜드 색 변경이
/// 필요해져도 이 파일 하나만 고치면 된다.
class AppTheme {
  const AppTheme._();

  /// 브랜드 시드 색 — 여기서 M3 색 스킴 전체가 파생된다.
  static const Color _seed = Color(0xFF2563EB);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48), // 기사 앱은 장갑 낀 손으로도 눌러야 한다
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
    );
  }
}
