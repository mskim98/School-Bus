import 'package:flutter/material.dart';

/// 타이포 스케일.
///
/// 화면에서 `TextStyle(fontSize: 17)` 처럼 스타일을 직접 만들지 않는다
/// (`docs/DESIGN_SYSTEM.md` §7-2) — `Theme.of(context).textTheme` 슬롯을 쓴다.
/// 여기는 그 슬롯에 무엇을 넣을지 정하는 유일한 자리다.
///
/// ⚠️ **폰트 파일을 번들하지 않는다**(§2.2). 시안은 Noto Sans KR / Roboto Mono
/// 를 쓰지만, 한글 웹폰트는 서브셋해도 현재 번들(2.2MB)보다 커지고 기사 앱은
/// 차 안 LTE 가 전제라 초기 로딩이 곧 사용성이다. 크기·굵기·행간만으로
/// 요구(본문 최소 15px 등)는 전부 만족된다.
class AppTypography {
  const AppTypography._();

  /// 시안의 8단 스케일을 M3 슬롯에 얹은 것.
  ///
  /// `bodyLarge` 와 `bodyMedium` 이 둘 다 15 인 건 의도다 — 지시서가
  /// "기사 앱 본문 최소 15px"을 요구하는데 위젯이 기본으로 집어드는 슬롯이
  /// `bodyMedium`(M3 기본 14)이라, 여기를 올려두지 않으면 바닥이 뚫린다.
  static TextTheme textTheme(ColorScheme scheme) {
    return TextTheme(
      // 운행 종료 요약 등 큰 수치
      displaySmall: const TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.4,
      ),
      // 화면 제목
      headlineSmall: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      // AppBar 제목
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      // 학생 이름 · 정차 카드 제목
      titleMedium: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      // 섹션 소제목
      titleSmall: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      // 본문
      bodyLarge: const TextStyle(fontSize: 15, height: 1.5),
      bodyMedium: const TextStyle(fontSize: 15, height: 1.5),
      // 보조 텍스트(정류장·하차지)
      bodySmall: const TextStyle(fontSize: 13, height: 1.45),
      // 액션 버튼
      labelLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.0,
      ),
      // 상태 칩
      labelMedium: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.0,
      ),
      // 태그 · NEW 배지
      labelSmall: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.0,
      ),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }

  /// 수치·시각 표기용.
  ///
  /// 시안의 Mono 역할(Roboto Mono) 대체다. 폰트를 번들하지 않는 대신
  /// **자릿수 고정(`tabularFigures`)** 만 가져온다 — 시각(`14:05`)·거리·인원수가
  /// 갱신될 때 숫자 폭이 흔들리지 않게 하는 게 Mono 를 쓴 원래 목적이다.
  static TextStyle mono(BuildContext context) {
    return (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
        .copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 0.2,
        );
  }

  /// 캡션(시안 400/12/1.4). `bodySmall` 보다 한 단 작다.
  static TextStyle caption(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      fontSize: 12,
      height: 1.4,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
}
