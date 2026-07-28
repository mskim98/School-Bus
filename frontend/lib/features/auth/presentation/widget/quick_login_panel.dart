import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
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
///
/// 로그인 폼과 **테두리로 분리된 카드**로 그린다. 폼 안에 섞어 두면 이 영역이
/// 빠지는 운영 빌드에서 화면이 잘려 보이고, 개발 빌드에서는 이게 제품의 일부인지
/// 도구인지 구분되지 않는다. `DEV ONLY` 태그가 그 구분을 글자로도 남긴다.
class QuickLoginPanel extends ConsumerWidget {
  const QuickLoginPanel({super.key, required this.enabled});

  /// 로그인 진행 중이면 false — 중복 제출을 막는다.
  final bool enabled;

  static const _seedPassword = 'password';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppTag(label: 'DEV ONLY', tone: AppTone.neutral),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '빠른 로그인',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.smd),
          for (var i = 0; i < _accounts.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _AccountButton(
              account: _accounts[i],
              enabled: enabled,
              onTap: () => ref
                  .read(authControllerProvider.notifier)
                  .login(email: _accounts[i].email, password: _seedPassword),
            ),
          ],
          const SizedBox(height: AppSpacing.smd),
          Text(
            '시드 계정으로 실제 로그인합니다 (비밀번호 password). '
            '운영 빌드에서는 ENABLE_QUICK_LOGIN 이 꺼져 이 영역이 사라집니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
    final scheme = theme.colorScheme;
    final isOutOfScope = !account.role.isSupportedInMvp;
    final foreground = isOutOfScope
        ? scheme.onSurfaceVariant
        : scheme.onSurface;

    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        backgroundColor: scheme.surface,
        foregroundColor: foreground,
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.smd,
          vertical: AppSpacing.sm,
        ),
      ),
      child: Row(
        children: [
          Icon(account.icon, size: 20),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.label, style: theme.textTheme.titleSmall),
                if (account.note != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    account.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}
