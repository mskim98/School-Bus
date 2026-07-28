import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/route_plan.dart';

/// 정차 순서 목록의 한 줄.
///
/// ⚠️ **학생 이름을 아직 못 보여준다.** 노선 API(`stops[]`)는 `studentId` 만 주고
/// 이름은 운행 세션 명단에서만 온다(계획서 §3.11). C7 에서 운행 세션을 붙이면
/// 이 자리에 이름이 들어간다 — 그때까지는 정차 순번을 앞세워 순서만 읽히게 한다.
class RouteStopTile extends StatelessWidget {
  const RouteStopTile({
    super.key,
    required this.stop,
    this.isNext = false,
    this.isLast = false,
    this.studentName,
  });

  final RouteStop stop;

  /// 다음에 가야 할 정차 — 운전 중 한눈에 들어와야 한다.
  final bool isNext;

  final bool isLast;

  /// C7 에서 운행 세션 명단이 붙으면 채워진다.
  final String? studentName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      color: isNext ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // 순번 원형 — 지도 마커의 숫자와 같은 값이라 서로 대응시켜 볼 수 있다.
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isNext ? scheme.primary : scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${stop.seq}',
              style: TextStyle(
                color: isNext ? scheme.onPrimary : scheme.onSecondaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName ?? '학생 #${stop.studentId}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (isNext)
                  Text(
                    '다음 정차',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (isLast)
                  Text(
                    '마지막 정차',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
              ],
            ),
          ),

          // ETA 는 서버가 초로 주므로 사람이 읽는 형태로 바꿔 보여준다.
          Text(
            stop.etaLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: isNext ? scheme.primary : theme.hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
