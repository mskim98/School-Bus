import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/config/feature_flags.dart';
import '../../../../core/ui/app_action_button.dart';
import '../../../../core/ui/app_tone.dart';
import '../../../../core/ui/error_message.dart';
import '../../../../shared/domain/role.dart';
import '../../application/auth_controller.dart';
import '../widget/quick_login_panel.dart';

/// 로그인 화면. 모든 역할이 같은 화면을 쓰고, 진입 화면 분기는 라우터가 한다(C5).
///
/// **회원가입·비밀번호 찾기는 없다**(지시서 §5.1) — 계정은 관리자가 만든다.
/// 없는 출구를 그려 두면 기사가 그 길을 눌러 보고 막힌 뒤에야 관리자를 찾는다.
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
    final isSubmitting = auth.isLoading;

    // MVP 는 기사·관리자 화면만 만든다. 학생·학부모로 로그인하면 계정 문제가
    // 아니라 "아직 화면이 없다"는 걸 분명히 알려야 사용자가 헤매지 않는다.
    final unsupportedRole = auth.value?.role.isSupportedInMvp == false
        ? auth.value!.role
        : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandHeader(),
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
                    const SizedBox(height: AppSpacing.md),

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

                    // 서버가 준 message 를 그대로 보여준다 — 문구를 다시 쓰지 않는다(컨벤션 §7-2).
                    if (auth.hasError) ...[
                      const SizedBox(height: AppSpacing.md),
                      ErrorBanner(error: auth.error!),
                    ],

                    if (unsupportedRole != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _UnsupportedRoleNotice(role: unsupportedRole),
                    ],

                    const SizedBox(height: AppSpacing.lg),
                    AppActionButton(
                      label: '로그인',
                      tone: AppTone.primary,
                      primaryAction: true,
                      busy: isSubmitting,
                      onPressed: _submit,
                    ),

                    // 개발 빌드에만 붙는다. 카드로 떼어 둔 건 이 영역이 사라져도
                    // 위 폼이 그대로 완결돼 보이게 하기 위해서다(지시서 §5.1).
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
      ),
    );
  }
}

/// 로고 + 서비스명.
///
/// 학원 이름을 넣지 않는다 — 로그인 전에는 어느 학원 계정인지 알 수 없다.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: AppTouch.min,
          height: AppTouch.min,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(
            Icons.directions_bus_rounded,
            size: 24,
            color: theme.colorScheme.onPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.smd),
        Text('학원 통학버스', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '운행 기록 · 관제',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// MVP 범위 밖 역할로 로그인했을 때의 안내.
///
/// 실패가 아니라 **정보**라 `errorContainer` 를 쓰지 않는다 — 계정은 정상이고
/// 화면만 없는 상황이라 빨간색으로 그리면 기사가 비밀번호를 다시 친다.
/// 정보 배너는 `primaryContainer`(`DESIGN_SYSTEM.md` §1.1)다.
class _UnsupportedRoleNotice extends ConsumerWidget {
  const _UnsupportedRoleNotice({required this.role});

  final Role role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final foreground = AppTone.primary.onContainer(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.smd),
      decoration: BoxDecoration(
        color: AppTone.primary.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${role.label} 화면은 아직 준비 중입니다',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '현재 버전은 운전기사와 관리자 화면만 제공합니다.',
            style: theme.textTheme.bodySmall?.copyWith(color: foreground),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: const Text('다른 계정으로 로그인'),
            ),
          ),
        ],
      ),
    );
  }
}
