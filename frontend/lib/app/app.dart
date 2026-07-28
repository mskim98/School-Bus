import 'package:flutter/material.dart';

import '../core/api/api_config.dart';
import 'theme/app_spacing.dart';
import 'theme/app_theme.dart';

/// 앱 셸. 라우팅·테마만 조립하고 개별 기능 화면은 두지 않는다(컨벤션 §2).
///
/// C5 에서 [MaterialApp] → [MaterialApp.router] 로 바꾸고 go_router 를 연결한다.
/// 그때 [home] 자리의 임시 화면은 제거된다.
class SchoolBusApp extends StatelessWidget {
  const SchoolBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '학원 통학버스',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _ScaffoldingCheckScreen(),
    );
  }
}

/// ⚠️ C1(스캐폴딩) 임시 화면 — C4(로그인)에서 삭제한다.
///
/// `--dart-define=API_BASE_URL` 이 실제로 빌드에 꽂혔는지 눈으로 확인하는 용도다.
/// Docker 빌드와 로컬 실행이 서로 다른 주소를 보는 사고가 흔해서, 부팅 화면에
/// 접속 대상을 띄워두면 초기 연동 단계에서 원인 파악이 빨라진다.
class _ScaffoldingCheckScreen extends StatelessWidget {
  const _ScaffoldingCheckScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_bus_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('학원 통학버스', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'C1 스캐폴딩 — 로그인 화면은 C4 에서 붙습니다',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _ConfigRow(label: 'API', value: ApiConfig.apiBaseUrl),
            _ConfigRow(label: 'WS', value: ApiConfig.wsUrl),
          ],
        ),
      ),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          SelectableText(
            value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
