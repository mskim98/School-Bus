import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// 앱 셸. 라우팅·테마만 조립하고 개별 기능 화면은 두지 않는다(컨벤션 §2).
class SchoolBusApp extends ConsumerWidget {
  const SchoolBusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: '학원 통학버스',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // 라이트 고정 — 시안(`docs/design/source/*.dc.html`)이 라이트 한 벌만 그렸고,
      // 기기 설정이 다크면 시안과 대조할 화면이 아예 달라져 검수가 불가능해진다.
      // `AppTheme.dark` 는 §1 표의 다크 열을 코드로 들고 있어야 해서 남겨 둔다.
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
