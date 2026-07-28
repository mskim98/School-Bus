import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// 아직 구현되지 않은 화면의 자리표시자.
///
/// 라우팅 골격을 먼저 세우고 화면은 나중에 채우기 때문에, 빈 화면 대신
/// **어느 작업 항목에서 채워지는지**를 적어 둔다 — 여러 사람(에이전트 포함)이
/// 나눠 작업할 때 "여긴 아직 안 된 것"과 "고장난 것"을 헷갈리지 않게 하기 위함이다.
class PendingScreen extends StatelessWidget {
  const PendingScreen({
    super.key,
    required this.title,
    required this.workItem,
    required this.description,
  });

  /// 화면 이름 (예: '오늘의 노선')
  final String title;

  /// 이 화면을 채우는 백로그 항목 (예: 'C6')
  final String workItem;

  /// 이 화면이 무엇을 할 예정인지 한 줄
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: AppSpacing.md),
            Chip(
              label: Text('$workItem 에서 구현'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
