import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../domain/monitored_bus.dart';

/// 관제 목록의 버스 한 줄.
///
/// "위치 없음"을 **에러가 아니라 상태로** 보여준다 — 아직 한 번도 보고하지 않은
/// 버스는 응답 배열에 아예 없기 때문에(계획서 §3.6), 목록에서 빠지면 관리자는
/// 그 버스가 사라진 줄 안다.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final position = bus.position;
    final staleness = bus.staleness(now);
    final isStale = staleness != null && staleness > staleAfter;

    final (IconData icon, Color color, String status) = switch (position) {
      null => (
        Icons.location_disabled_outlined,
        theme.colorScheme.outline,
        '위치 보고 없음',
      ),
      _ when isStale => (
        Icons.warning_amber_outlined,
        theme.colorScheme.error,
        '${_elapsedLabel(staleness)} 갱신 없음',
      ),
      _ => (
        Icons.directions_bus,
        theme.colorScheme.primary,
        '${_elapsedLabel(staleness)} 수신 · ${position.origin.label}',
      ),
    };

    return ListTile(
      selected: selected,
      onTap: onTap,
      leading: Icon(icon, color: color),
      title: Text(bus.name.isEmpty ? '버스 ${bus.busId}' : bus.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
          Text(
            _subtitleOf(bus),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      trailing: position == null
          ? null
          : const Icon(Icons.my_location, size: 16),
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
