import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/app_tone.dart';

/// 배차에서 **제외된 학생** 경고.
///
/// ⚠️ 서버 응답 `excludedStudentNames` 는 에러가 아니라 정상 응답의 일부다.
/// 승하차 좌표가 없어 배정에서 빠진 학생들이며, 이걸 안 보여주면 관리자가
/// 학생이 통째로 누락된 걸 모른 채 확정한다. 그래서 성공 화면 안에서도 눈에 띄게 띄운다.
///
/// 톤은 [AppTone.warning] 이다 — 실패([AppTone.error])가 아니라 **확정 전에 봐야 할
/// 주의**다. 빨강으로 그리면 요청이 실패한 줄 알고 다시 제안을 받는다.
class ExcludedStudentsBanner extends StatelessWidget {
  const ExcludedStudentsBanner({super.key, required this.studentNames});

  final List<String> studentNames;

  @override
  Widget build(BuildContext context) {
    if (studentNames.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final foreground = AppTone.warning.onContainer(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTone.warning.container(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppTone.warning.solid(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: foreground, size: 20),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '배차에서 제외된 학생 ${studentNames.length}명',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  studentNames.join(', '),
                  style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '승하차 좌표가 없어 어느 버스에도 배정되지 않았습니다. '
                  '학생 정보에 좌표를 넣고 다시 제안받아야 이 노선에 포함됩니다.',
                  style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
