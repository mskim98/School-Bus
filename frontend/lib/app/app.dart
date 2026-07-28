import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_config.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/screen/login_screen.dart';
import '../shared/domain/auth_session.dart';
import 'theme/app_spacing.dart';
import 'theme/app_theme.dart';

/// 앱 셸. 라우팅·테마만 조립하고 개별 기능 화면은 두지 않는다(컨벤션 §2).
///
/// C5 에서 [MaterialApp] → [MaterialApp.router] 로 바꾸고 go_router 를 연결한다.
class SchoolBusApp extends StatelessWidget {
  const SchoolBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '학원 통학버스',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _SessionGate(),
    );
  }
}

/// ⚠️ C4 임시 분기 — C5 에서 go_router 의 redirect 가드로 대체한다.
///
/// 지금은 "로그인 됐는가"만 보고 화면을 고른다. 역할별 경로 분기·딥링크·뒤로가기는
/// 라우터가 할 일이라 여기서 흉내내지 않는다.
class _SessionGate extends ConsumerWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    // 앱 시작 직후 저장된 토큰을 읽는 동안(첫 로딩)에는 스플래시를 띄운다.
    // 로그인 제출 중(hasValue=true 이면서 loading)에는 로그인 화면이 그대로 있어야
    // 입력값과 에러가 사라지지 않는다.
    if (auth.isLoading && !auth.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = auth.value;
    if (session == null || !session.role.isSupportedInMvp) {
      return const LoginScreen();
    }
    return _SignedInPlaceholder(session: session);
  }
}

/// ⚠️ C5~C11 에서 실제 화면(기사/관리자)으로 대체된다.
/// 지금은 로그인·토큰 해석이 제대로 됐는지 눈으로 확인하는 용도다.
class _SignedInPlaceholder extends ConsumerWidget {
  const _SignedInPlaceholder({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인 확인'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(session.role.label, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            _Row(label: 'userId', value: '${session.userId}'),
            _Row(label: 'email', value: session.email),
            _Row(label: 'tenantId', value: '${session.tenantId ?? '(없음)'}'),
            _Row(label: 'busId', value: '${session.busId ?? '(C6에서 조회)'}'),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'API ${ApiConfig.apiBaseUrl}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

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
            width: 80,
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
