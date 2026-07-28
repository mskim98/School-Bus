import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';

/// 플랫폼 관리자용 **고정 학원 id** (계획서 §8 D3 확정).
///
/// `PLATFORM_ADMIN` 은 소속 학원이 없어 JWT `memberships` 의 tenantId 자리가 비어 있는데,
/// 배차·노선 API 는 tenantId 를 요구한다. 학원 목록 API(`/api/tenants`)가 MVP 범위 밖이라
/// 학원 선택 UI 를 만들 수 없어서, 시드 기준 1번 학원으로 고정하고 **화면에 고정값임을 표시**한다.
///
/// 컨벤션 §8 이 금지하는 "하드코딩된 tenantId" 의 유일한 예외다 — 다른 곳에서 숫자를
/// 직접 쓰지 말고 반드시 [adminTenantProvider] 를 거친다.
const int platformAdminFallbackTenantId = 1;

/// 관리자 화면이 조회 대상으로 삼을 학원.
class AdminTenant {
  const AdminTenant({required this.id, required this.isFixedFallback});

  final int id;

  /// 사용자 소속이 아니라 코드에 박힌 기본값인가.
  /// true 면 화면이 "고정값" 배지를 띄워, 다른 학원을 보고 있다고 오해하지 않게 한다.
  final bool isFixedFallback;
}

/// 현재 관리자의 학원. 관리자가 아니거나 로그인 전이면 null.
///
/// 학원 관리자는 세션(JWT)의 tenantId 를 그대로 쓰고, 플랫폼 관리자만
/// [platformAdminFallbackTenantId] 로 떨어진다.
final adminTenantProvider = Provider<AdminTenant?>((ref) {
  final session = ref.watch(currentSessionProvider);
  if (session == null || !session.role.isAdmin) return null;

  final tenantId = session.tenantId;
  if (tenantId != null) {
    return AdminTenant(id: tenantId, isFixedFallback: false);
  }
  return const AdminTenant(
    id: platformAdminFallbackTenantId,
    isFixedFallback: true,
  );
});
