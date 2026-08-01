import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bus_repository.dart';
import '../data/dto/bus_dto.dart';

/// `busId → 버스` 를 찾아주는 명부.
///
/// 노선 계획·배차 제안·관제 지도가 전부 `busId` 만 들고 다닌다. 이름·정원은 버스
/// API 에만 있어서, 세 화면이 각자 부르면 같은 목록을 세 번 받고 한 화면 안에서
/// 어떤 카드는 `3호차`, 어떤 카드는 `버스 #1` 로 엇갈린다.
class BusDirectory {
  const BusDirectory(this._byId);

  const BusDirectory.empty() : this(const {});

  final Map<int, BusDto> _byId;

  bool get isEmpty => _byId.isEmpty;

  Iterable<BusDto> get all => _byId.values;

  BusDto? find(int busId) => _byId[busId];

  /// 화면에 그대로 쓰는 호차명. 모르면 `버스 #id` — 그럴듯한 이름을 지어내지 않는다.
  String nameOf(int busId) {
    final name = _byId[busId]?.name?.trim();
    return (name == null || name.isEmpty) ? '버스 #$busId' : name;
  }

  /// 좌석 수. 모르면 null — **0 으로 채우면 "정원 초과"로 잘못 읽힌다.**
  int? seatCapacityOf(int busId) => _byId[busId]?.seatCapacity;

  static BusDirectory fromList(List<BusDto> buses) =>
      BusDirectory({for (final b in buses) b.id: b});
}

/// 학원 하나의 버스 명부. 학원이 바뀌면 자동으로 다시 받는다.
final busDirectoryProvider = FutureProvider.family<BusDirectory, int>((
  ref,
  tenantId,
) async {
  final buses = await ref.read(busRepositoryProvider).list(tenantId: tenantId);
  return BusDirectory.fromList(buses);
});
