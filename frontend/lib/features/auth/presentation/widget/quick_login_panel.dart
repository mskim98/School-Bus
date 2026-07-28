import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/domain/role.dart';
import '../../application/auth_controller.dart';

/// 시드 계정 하나.
class _SeedAccount {
  const _SeedAccount({
    required this.label,
    required this.email,
    required this.role,
    required this.icon,
    this.note,
  });

  final String label;
  final String email;
  final Role role;
  final IconData icon;

  /// 이 계정으로 무엇을 확인할 수 있는지
  final String? note;
}

/// Flyway 로컬 시드(`V2__seed_data.sql`)의 계정들. 비밀번호는 전부 `password`.
///
/// ⚠️ **선탑자(동승보호자) 전용 계정은 없다.** `Role` enum 자체에 그 역할이 없고
/// `DRIVER` 로 흡수하기로 확정돼 있다(`MVP_RELEASE_TRACKER.md` §0,
/// `PROJECT_MASTER_PLAN.md` §12.1). 기사 버튼 하나가 두 역할을 모두 대표한다.
const _accounts = <_SeedAccount>[
  _SeedAccount(
    label: '운전기사 (박기사)',
    email: 'driver@school.com',
    role: Role.driver,
    icon: Icons.airline_seat_recline_normal,
    note: '3호차 담당 · 모바일 뷰 · 선탑자도 이 역할을 쓴다',
  ),
  _SeedAccount(
    label: '학원 관리자 (한빛)',
    email: 'admin@school.com',
    role: Role.academyAdmin,
    icon: Icons.admin_panel_settings_outlined,
    note: '한빛학원(tenantId=1) 관제',
  ),
  _SeedAccount(
    label: '플랫폼 관리자',
    email: 'platform@school.com',
    role: Role.platformAdmin,
    icon: Icons.public,
    note: '소속 학원 없음 — tenantId 가 null 인 경로 확인용',
  ),
  _SeedAccount(
    label: '학생 (김민준)',
    email: 'student@school.com',
    role: Role.student,
    icon: Icons.school_outlined,
    note: 'MVP 범위 밖 — "준비 중" 안내가 뜨는지 확인용',
  ),
];

/// 기능 테스트용 빠른 로그인.
///
/// 인증을 건너뛰지 않는다 — 시드 계정으로 **정상 로그인**을 대신 눌러줄 뿐이라
/// 토큰·역할 분기·API 호출이 실제와 똑같이 동작한다.
/// 노출 여부는 `FeatureFlags.enableQuickLogin` 이 정한다.
class QuickLoginPanel extends ConsumerWidget {
  const QuickLoginPanel({super.key, required this.enabled});

  /// 로그인 진행 중이면 false — 중복 제출을 막는다.
  final bool enabled;

  static const _seedPassword = 'password';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                '기능 테스트용 빠른 로그인',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
            Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final account in _accounts) ...[
          _AccountButton(
            account: account,
            enabled: enabled,
            onTap: () => ref
                .read(authControllerProvider.notifier)
                .login(email: account.email, password: _seedPassword),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          '시드 계정으로 실제 로그인합니다 (비밀번호 password). '
          '운영 빌드에서는 ENABLE_QUICK_LOGIN 이 꺼져 이 영역이 사라집니다.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
        ),
      ],
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.account,
    required this.enabled,
    required this.onTap,
  });

  final _SeedAccount account;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOutOfScope = !account.role.isSupportedInMvp;

    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        foregroundColor: isOutOfScope ? theme.hintColor : null,
      ),
      child: Row(
        children: [
          Icon(account.icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (account.note != null)
                  Text(
                    account.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}
