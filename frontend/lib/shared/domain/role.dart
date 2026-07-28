/// 사용자 역할. 백엔드 `Role` enum 과 이름이 정확히 일치해야 한다
/// (JWT `memberships` 클레임에 이 문자열이 그대로 실려 온다).
enum Role {
  student('STUDENT', '학생'),
  parent('PARENT', '학부모'),
  driver('DRIVER', '운전기사'),
  academyAdmin('ACADEMY_ADMIN', '학원 관리자'),
  platformAdmin('PLATFORM_ADMIN', '플랫폼 관리자');

  const Role(this.wireName, this.label);

  /// 서버가 쓰는 문자열
  final String wireName;

  /// 화면에 보여줄 한글 이름
  final String label;

  /// 모르는 값이면 null — 서버에 역할이 추가돼도 앱이 죽지 않게 한다.
  static Role? fromWire(String? value) {
    for (final role in Role.values) {
      if (role.wireName == value) return role;
    }
    return null;
  }

  /// 관제 화면(관리자 레이아웃)을 쓰는 역할인가.
  bool get isAdmin => this == Role.academyAdmin || this == Role.platformAdmin;

  /// MVP 범위에 포함된 역할인가.
  ///
  /// 학생·학부모는 백엔드 API 는 있지만 화면을 만들지 않는다(계획서 §0).
  /// 그 계정으로 로그인하면 "지원하지 않는 역할" 안내를 띄운다.
  bool get isSupportedInMvp => this == Role.driver || isAdmin;
}
