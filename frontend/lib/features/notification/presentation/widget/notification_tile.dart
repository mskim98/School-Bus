import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../data/dto/notification_dto.dart';

/// 알림 한 줄 — `docs/DESIGN_SYSTEM.md` §5.2 명세를 그대로 옮긴 것.
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

  /// 좌측 원형 아이콘 지름(§5.2). 터치 타깃이 아니라 표기라 48 이 아니다 —
  /// 행 전체가 눌리지도 않는다.
  static const _iconSize = 40.0;

  final NotificationDto notification;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = _NotificationKind.of(notification.type);

    return Container(
      // 새 알림만 바탕을 깐다. 읽은 것은 투명 — 전부 칠하면 새 것이 안 보인다.
      color: isNew ? scheme.surfaceContainer : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: _iconSize,
            height: _iconSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kind.tone.container(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              kind.icon,
              size: 20,
              color: kind.tone.onContainer(context),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 유형 라벨과 NEW 배지는 글자가 커지면 줄바꿈된다 — 고정 Row 로 두면
                // 200% 확대에서 배지가 잘린다(§7-5).
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      kind.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (isNew)
                      const AppTag(
                        label: 'NEW',
                        tone: AppTone.primary,
                        filled: true,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // 서버 문구를 그대로 보여준다 — 앱이 다시 쓰지 않는다(컨벤션 §7-2).
                Text(notification.message, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // 시각은 세로로 쌓이는 목록이라 자릿수를 고정한다(§2.1 Mono).
          Text(
            _formatTime(notification.createdAt),
            style: AppTypography.mono(
              context,
            ).copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// 서버 `NotificationType` 문자열 → 아이콘·한글 이름·의미 톤.
///
/// DTO 를 enum 으로 좁히지 않고 여기서 푸는 이유(컨벤션 §4) — 이건 **표시**의 문제다.
/// 서버에 종류가 추가돼도 목록 파싱이 깨지지 않고, 모르는 값은 [_unknown] 으로 떨어진다.
///
/// 톤 배정은 디자인 시스템 §5.2 가 정한 것이다 —
/// 미승차 `error` · 근접 `primary` · 승하차 `success` · 노선 배포 `neutral`.
enum _NotificationKind {
  boardDone('BOARD_DONE', '승차', Icons.login, AppTone.success),
  alightDone('ALIGHT_DONE', '하차', Icons.logout, AppTone.success),
  handoverDone(
    'HANDOVER_DONE',
    '인계',
    Icons.handshake_outlined,
    AppTone.success,
  ),
  approach('APPROACH', '곧 도착', Icons.near_me_outlined, AppTone.primary),
  noShow('NO_SHOW', '미승차', Icons.person_off_outlined, AppTone.error),
  sos('SOS', '긴급', Icons.emergency_outlined, AppTone.error),
  scheduleResult(
    'SCHEDULE_RESULT',
    '일정 변경',
    Icons.event_available_outlined,
    AppTone.neutral,
  ),
  connectionLost('CONNECTION_LOST', '연결 끊김', Icons.wifi_off, AppTone.error),
  routeRecommended(
    'ROUTE_RECOMMENDED',
    '배차 제안',
    Icons.alt_route,
    AppTone.neutral,
  ),
  routePublished('ROUTE_PUBLISHED', '노선 배포', Icons.route, AppTone.neutral),
  _unknown('', '알림', Icons.notifications_none, AppTone.neutral);

  const _NotificationKind(this.wireName, this.label, this.icon, this.tone);

  final String wireName;
  final String label;
  final IconData icon;

  /// 의미 톤. 색은 [AppTone] 이 해석하고 여기서는 고르지 않는다(§5.1).
  final AppTone tone;

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
