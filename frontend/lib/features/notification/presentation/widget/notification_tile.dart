import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../data/dto/notification_dto.dart';

/// 알림 한 줄.
///
/// [isNew] 는 "이 화면을 연 뒤 실시간으로 도착한 것"이라는 뜻이다. 배경색과 배지로
/// 구분한다 — WebSocket 으로 밀려온 항목이 이력 사이에 조용히 섞이면 사용자가
/// 새로 뭔가 일어났다는 걸 알아채지 못한다.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.isNew = false,
  });

  final NotificationDto notification;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = _NotificationKind.of(notification.type);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isNew ? scheme.primaryContainer : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(kind.icon, size: 18, color: kind.colorOf(scheme)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      kind.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: kind.colorOf(scheme),
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _NewBadge(scheme: scheme),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // 서버 문구를 그대로 보여준다 — 앱이 다시 쓰지 않는다(컨벤션 §7-2).
                Text(notification.message, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            _formatTime(notification.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        'NEW',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// 서버 `NotificationType` 문자열 → 아이콘·한글 이름.
///
/// DTO 를 enum 으로 좁히지 않고 여기서 푸는 이유(컨벤션 §4) — 이건 **표시**의 문제다.
/// 서버에 종류가 추가돼도 목록 파싱이 깨지지 않고, 모르는 값은 [_unknown] 으로 떨어진다.
enum _NotificationKind {
  boardDone('BOARD_DONE', '승차', Icons.login),
  alightDone('ALIGHT_DONE', '하차', Icons.logout),
  handoverDone('HANDOVER_DONE', '인계', Icons.handshake_outlined),
  approach('APPROACH', '곧 도착', Icons.near_me_outlined),
  noShow('NO_SHOW', '미승차', Icons.person_off_outlined, isAlert: true),
  sos('SOS', '긴급', Icons.emergency_outlined, isAlert: true),
  scheduleResult('SCHEDULE_RESULT', '일정 변경', Icons.event_available_outlined),
  connectionLost('CONNECTION_LOST', '연결 끊김', Icons.wifi_off, isAlert: true),
  routeRecommended('ROUTE_RECOMMENDED', '배차 제안', Icons.alt_route),
  routePublished('ROUTE_PUBLISHED', '노선 배포', Icons.route),
  _unknown('', '알림', Icons.notifications_none);

  const _NotificationKind(
    this.wireName,
    this.label,
    this.icon, {
    this.isAlert = false,
  });

  final String wireName;
  final String label;
  final IconData icon;

  /// 사용자가 즉시 대응해야 하는 종류인가. 색으로만 구분한다.
  final bool isAlert;

  Color colorOf(ColorScheme scheme) =>
      isAlert ? scheme.error : scheme.onSurfaceVariant;

  static _NotificationKind of(String wireName) {
    for (final kind in _NotificationKind.values) {
      if (kind.wireName == wireName) return kind;
    }
    return _unknown;
  }
}

/// `HH:mm` — 오늘이 아니면 `M/d HH:mm`.
///
/// `intl` 을 넣지 않는다. 형식이 이거 하나라 패키지를 더할 값어치가 없다.
String _formatTime(DateTime at) {
  final now = DateTime.now();
  final isToday =
      at.year == now.year && at.month == now.month && at.day == now.day;
  final time =
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
  return isToday ? time : '${at.month}/${at.day} $time';
}
