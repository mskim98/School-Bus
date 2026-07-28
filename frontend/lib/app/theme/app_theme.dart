import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 앱 테마 단일 정의.
///
/// 색·타이포를 화면에서 직접 만들지 않는다 — 여기서만 정의하고 화면은
/// `Theme.of(context)` 로 읽는다(컨벤션 §8). 다크 테마나 브랜드 색 변경이
/// 필요해져도 이 파일 하나만 고치면 된다.
///
/// 근거: `docs/DESIGN_SYSTEM.md`
class AppTheme {
  const AppTheme._();

  /// 브랜드 시드 색 — 여기서 M3 색 스킴 전체가 파생된다.
  static const Color _seed = Color(0xFF2563EB);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  /// 시드 파생 스킴 위에 **디자인 시스템이 손으로 정한 5개 역할만** 덮는다.
  ///
  /// 시안은 "시드로 `fromSeed` 하면 자동 대응된다"고 적었지만 실제로는
  /// 아래 5개가 다르다(Flutter 3.44.8 실측, `DESIGN_SYSTEM.md` §1.2).
  /// 특히 라이트 `primary` 는 M3 톤 팔레트가 `#4B5C92` 로 채도를 크게 깎아
  /// **직사광선 대비 요구**(지시서 §3)에 미달한다.
  ///
  /// 팔레트를 손으로 다시 짜지 않는 이유: 그러면 앞으로 M3 가 쓰는 다른
  /// 역할색(`secondary`·`tertiary`·`inverseSurface` …)이 시드와 어긋난다.
  static ColorScheme _scheme(Brightness brightness) {
    final base = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

    if (brightness == Brightness.light) {
      return base.copyWith(
        primary: const Color(0xFF1D4ED8),
        onPrimaryContainer: const Color(0xFF001945),
        onErrorContainer: const Color(0xFF410002),
      );
    }
    return base.copyWith(
      onPrimary: const Color(0xFF052978),
      primaryContainer: const Color(0xFF123FA8),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final scheme = _scheme(brightness);
    final textTheme = AppTypography.textTheme(scheme);

    // 탭 가능한 요소는 전부 48dp 이상이어야 한다(§3.3). 버튼마다 챙기면
    // 반드시 빠뜨리는 곳이 생기므로 테마에서 한 번에 보장한다.
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[
        brightness == Brightness.light ? AppColors.light : AppColors.dark,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      // 카드는 그림자 대신 1px 테두리로 구분한다(§3.4).
      // 그림자는 지도 위 마커에만 쓴다 — 화면 전체가 떠 보이면 위계가 사라진다.
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        constraints: const BoxConstraints(minHeight: AppTouch.min),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTouch.min),
          textStyle: textTheme.labelLarge,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTouch.min),
          textStyle: textTheme.labelLarge,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppTouch.min, AppTouch.min),
          textStyle: textTheme.labelLarge,
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppTouch.min, AppTouch.min),
        ),
      ),
      // M3 기본값이 §3.3 미달이라 여기서 올린다 — SegmentedButton 40, Chip 32.
      // 히트 영역은 `materialTapTargetSize: padded` 덕에 48 이 나오지만 **보이는
      // 높이**가 작으면 흔들리는 차 안에서 조준할 표적이 그만큼 작다.
      // 화면마다 style 로 챙기면 반드시 빠뜨리므로 테마에서 한 번에 잡는다.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppTouch.min),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        // 선택 칩만 해당한다. 읽기 전용 표기는 AppStatusChip/AppTag 이고
        // 그건 M3 Chip 을 쓰지 않으므로 이 테마에 걸리지 않는다.
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.smd,
        ),
        labelStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
  }
}
