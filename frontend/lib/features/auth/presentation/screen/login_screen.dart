import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/ui/error_message.dart';
import '../../../../shared/domain/role.dart';
import '../../application/auth_controller.dart';
import '../widget/quick_login_panel.dart';

/// 로그인 화면. 모든 역할이 같은 화면을 쓰고, 진입 화면 분기는 라우터가 한다(C5).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isSubmitting = auth.isLoading;

    // MVP 는 기사·관리자 화면만 만든다. 학생·학부모로 로그인하면 계정 문제가
    // 아니라 "아직 화면이 없다"는 걸 분명히 알려야 사용자가 헤매지 않는다.
    final unsupportedRole = auth.value?.role.isSupportedInMvp == false
        ? auth.value!.role
        : null;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.directions_bus_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '학원 통학버스',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: '이메일'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    enabled: !isSubmitting,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? '이메일을 입력해 주세요'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: '비밀번호'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    enabled: !isSubmitting,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) => (value == null || value.isEmpty)
                        ? '비밀번호를 입력해 주세요'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 서버가 준 message 를 그대로 보여준다 — 문구를 다시 쓰지 않는다(컨벤션 §7-2).
                  if (auth.hasError) ...[
                    ErrorBanner(error: auth.error!),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  if (unsupportedRole != null) ...[
                    _UnsupportedRoleNotice(role: unsupportedRole),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  FilledButton(
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('로그인'),
                  ),

                  if (FeatureFlags.enableQuickLogin) ...[
                    const SizedBox(height: AppSpacing.lg),
                    QuickLoginPanel(enabled: !isSubmitting),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnsupportedRoleNotice extends ConsumerWidget {
  const _UnsupportedRoleNotice({required this.role});

  final Role role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${role.label} 화면은 아직 준비 중입니다',
            style: TextStyle(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '현재 버전은 운전기사와 관리자 화면만 제공합니다.',
            style: TextStyle(color: scheme.onSecondaryContainer),
          ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              child: const Text('다른 계정으로 로그인'),
            ),
          ),
        ],
      ),
    );
  }
}
