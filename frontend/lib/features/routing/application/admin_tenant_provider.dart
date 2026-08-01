import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../tenant/data/dto/tenant_dto.dart';
import '../../tenant/data/tenant_repository.dart';

/// 플랫폼 관리자가 아직 학원을 고르지 않았을 때 볼 학원.
///
/// 목록을 받아오기 전 한 프레임 동안만 쓰인다 — 목록이 도착하면 첫 학원으로
/// 대체된다. 예전에는 이 값이 **유일한 수단**이었는데(학원 목록 API 가 없다고
/// 판단했다), `GET /api/tenants`(`PLATFORM_ADMIN`)가 실재해 선택 UI 를 만들 수
/// 있었다. 컨벤션 §8 의 "하드코딩된 tenantId" 예외는 이제 이 폴백 하나뿐이다.
const int platformAdminFallbackTenantId = 1;

/// 관리자 화면이 조회 대상으로 삼을 학원.
class AdminTenant {
  const AdminTenant({
    required this.id,
    required this.isFixedFallback,
    this.name,
    this.canSwitch = false,
  });

  final int id;

  /// 사용자 소속이 아니라 코드에 박힌 기본값인가.
  /// true 면 화면이 "고정값" 배지를 띄워, 다른 학원을 보고 있다고 오해하지 않게 한다.
  final bool isFixedFallback;

  /// 학원 이름. 목록을 못 받았으면 null 이고, 그때 화면은 id 만 보여준다.
  final String? name;

  /// 다른 학원으로 바꿀 수 있는가(플랫폼 관리자만 true).
  final bool canSwitch;
}

/// 플랫폼 관리자가 고른 학원 id. 안 골랐으면 null.
///
/// 학원 관리자에게는 의미가 없다 — 그쪽은 JWT 의 소속 학원에 묶여 있다.
class SelectedTenantId extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int tenantId) => state = tenantId;
}

final selectedTenantIdProvider = NotifierProvider<SelectedTenantId, int?>(
  SelectedTenantId.new,
);

/// 플랫폼 관리자가 고를 수 있는 학원 목록. 학원 관리자는 항상 빈 목록이다
/// (서버가 403 을 주고 repository 가 빈 목록으로 접는다).
final adminTenantOptionsProvider = FutureProvider<List<TenantDto>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  // 소속이 있는 관리자는 그 학원만 본다 — 목록을 부를 이유가 없다.
  if (session == null || !session.role.isAdmin || session.tenantId != null) {
    return const [];
  }
  return ref.read(tenantRepositoryProvider).list();
});

/// 현재 관리자의 학원. 관리자가 아니거나 로그인 전이면 null.
///
/// 학원 관리자는 세션(JWT)의 tenantId 를 그대로 쓰고, 플랫폼 관리자는 고른 학원을
/// 쓴다. 아직 안 골랐으면 목록의 첫 학원, 목록도 없으면
/// [platformAdminFallbackTenantId] 로 떨어진다.
final adminTenantProvider = Provider<AdminTenant?>((ref) {
  final session = ref.watch(currentSessionProvider);
  if (session == null || !session.role.isAdmin) return null;

  final tenantId = session.tenantId;
  if (tenantId != null) {
    return AdminTenant(id: tenantId, isFixedFallback: false);
  }

  final options = ref.watch(adminTenantOptionsProvider).value ?? const [];
  final selected = ref.watch(selectedTenantIdProvider);

  // 고른 학원이 목록에 없으면(로그아웃 후 다른 계정 등) 선택을 버린다.
  final chosen = options.where((t) => t.id == selected).firstOrNull;
  final effective = chosen ?? options.firstOrNull;

  return AdminTenant(
    id: effective?.id ?? platformAdminFallbackTenantId,
    // 고를 수 있는 상태면 더 이상 "코드에 박힌 값"이 아니다.
    isFixedFallback: effective == null,
    name: effective?.name,
    canSwitch: options.length > 1,
  );
});
