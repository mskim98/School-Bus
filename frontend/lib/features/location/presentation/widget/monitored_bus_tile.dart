import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/app_status_chip.dart';
import '../../../../core/ui/app_tone.dart';
import '../../domain/monitored_bus.dart';

/// 관제 목록의 버스 한 줄.
///
/// "위치 없음"을 **에러가 아니라 상태로** 보여준다 — 아직 한 번도 보고하지 않은
/// 버스는 응답 배열에 아예 없기 때문에(계획서 §3.6), 목록에서 빠지면 관리자는
/// 그 버스가 사라진 줄 안다.
///
/// 모양은 알림 행(§5.2)과 맞췄다 — 좌측 40 원형 아이콘 + 본문 + 우측 시각(mono).
/// 관제와 알림함이 같은 리듬으로 읽혀야 두 화면을 오갈 때 눈이 다시 훑지 않는다.
class MonitoredBusTile extends StatelessWidget {
  const MonitoredBusTile({
    super.key,
    required this.bus,
    required this.now,
    required this.selected,
    required this.onTap,
  });

  final MonitoredBus bus;

  /// 신선도 계산 기준 시각. 위젯마다 `DateTime.now()` 를 따로 부르면
  /// 같은 화면 안에서 초가 어긋나 보인다.
  final DateTime now;

  final bool selected;
  final VoidCallback onTap;

  /// 이 시간이 지나도록 새 좌표가 없으면 "끊김"으로 본다.
  /// 서버 갱신 3초 · 폴링 3초 기준으로 여유를 크게 잡은 값이다.
  static const staleAfter = Duration(seconds: 20);

  /// 좌측 원형 아이콘 지름(§5.2 알림 행과 동일).
  static const _iconSize = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final position = bus.position;
    final staleness = bus.staleness(now);
    final isStale = staleness != null && staleness > staleAfter;

    // 색·아이콘·라벨 3중 표기(§0-1). 관제는 태블릿으로 차 안에서도 보므로
    // 기사 앱과 같은 규칙을 그대로 적용한다.
    final (
      IconData icon,
      AppTone tone,
      String mark,
      String status,
    ) = switch (position) {
      null => (
        Icons.location_disabled_outlined,
        AppTone.neutral,
        '·',
        '위치 보고 없음',
      ),
      _ when isStale => (
        Icons.warning_amber_outlined,
        AppTone.error,
        '!',
        '갱신 끊김',
      ),
      _ => (Icons.directions_bus, AppTone.primary, '◎', '수신 중'),
    };

    return Material(
      // 선택된 줄은 지도에서 지금 보고 있는 대상이다 — 승차 칩과 같은 톤을 쓴다.
      color: selected ? scheme.primaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // 마우스로 쓴다고 줄이지 않는다(§10) — 태블릿 관제를 배제하지 않았다.
          constraints: const BoxConstraints(minHeight: AppTouch.min),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.smd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: _iconSize,
                height: _iconSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.container(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: tone.onContainer(context)),
              ),
              const SizedBox(width: AppSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.name.isEmpty ? '버스 ${bus.busId}' : bus.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _subtitleOf(bus),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppStatusChip(icon: mark, label: status, tone: tone),
                        if (position != null)
                          Text(
                            position.origin.label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 마지막으로 좌표를 받은 시각. 3초마다 갱신되므로 자릿수를 고정한다(§2.1).
              Text(
                position == null ? '—' : _elapsedLabel(staleness),
                style: AppTypography.mono(context).copyWith(
                  color: isStale ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitleOf(MonitoredBus bus) {
    final parts = [
      if (bus.plateNumber != null && bus.plateNumber!.isNotEmpty)
        bus.plateNumber!,
      // 기사가 없으면 "미배차" — 위치가 안 오는 이유가 대개 이것이다.
      bus.driverName == null || bus.driverName!.isEmpty
          ? '기사 미배차'
          : bus.driverName!,
    ];
    return parts.join(' · ');
  }

  /// `3초 전` / `2분 전` — 클라이언트가 좌표를 받은 시각 기준이다.
  static String _elapsedLabel(Duration? elapsed) {
    if (elapsed == null) return '방금';
    final seconds = elapsed.inSeconds;
    if (seconds < 5) return '방금';
    if (seconds < 60) return '$seconds초 전';
    final minutes = elapsed.inMinutes;
    if (minutes < 60) return '$minutes분 전';
    return '${elapsed.inHours}시간 전';
  }
}
