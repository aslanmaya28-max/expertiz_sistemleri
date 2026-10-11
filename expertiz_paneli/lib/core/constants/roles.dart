/// USER ROLE ENUM - SINGLE SOURCE OF TRUTH
///
/// Tüm sistemdeki tek rol tanımı.
/// Veritabanı (Supabase) ile birebir eşleşir.
///
/// ⚠️ NON-NEGOTIABLE: Bu dosya dışında UserRole tanımı YASAKTIR.
///
/// Veritabanı Değerleri:
/// - admin        → Sistem yöneticisi (Seviye: 0)
/// - field_staff  → Saha personeli   (Seviye: 1)
/// - customer     → Müşteri          (Seviye: 2)
enum UserRole {
  admin,
  fieldStaff,
  customer,
  unauthorized;

  /// Merkezi API ve eski veritabanı kayıtlarında kullanılan alternatif rol adları.
  /// Örn. admin panelinden eklenen personel backend'de 'personel' rolüyle tutulur.
  static const Map<String, UserRole> _aliases = {
    'personel': UserRole.fieldStaff,
    'personnel': UserRole.fieldStaff,
    'staff': UserRole.fieldStaff,
    'saha_personeli': UserRole.fieldStaff,
    'user': UserRole.customer,
    'musteri': UserRole.customer,
    'müşteri': UserRole.customer,
    'yonetici': UserRole.admin,
  };

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.unauthorized;
    final normalized = role.toLowerCase().trim();
    final alias = _aliases[normalized];
    if (alias != null) return alias;
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized ||
             e.toDatabaseValue == normalized,
      orElse: () => UserRole.unauthorized,
    );
  }

  static UserRole fromDatabaseValue(String value) => fromString(value);

  static UserRole fromLegacyRole(String? role) => fromString(role);
}

extension UserRoleExtension on UserRole {
  String get toDatabaseValue {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.fieldStaff:
        return 'field_staff';
      case UserRole.customer:
        return 'customer';
      case UserRole.unauthorized:
        return 'unauthorized';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Yönetici';
      case UserRole.fieldStaff:
        return 'Saha Personeli';
      case UserRole.customer:
        return 'Müşteri';
      case UserRole.unauthorized:
        return 'Yetkisiz';
    }
  }

  String get displayNameEn {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.fieldStaff:
        return 'Field Staff';
      case UserRole.customer:
        return 'Customer';
      case UserRole.unauthorized:
        return 'Unauthorized';
    }
  }

  int get authorityLevel {
    switch (this) {
      case UserRole.admin:
        return 0;
      case UserRole.fieldStaff:
        return 1;
      case UserRole.customer:
        return 2;
      case UserRole.unauthorized:
        return 99;
    }
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isFieldStaff => this == UserRole.fieldStaff;
  bool get isCustomer => this == UserRole.customer;
  bool get isUnauthorized => this == UserRole.unauthorized;

  bool canAssignRole(UserRole targetRole) =>
      targetRole.authorityLevel > authorityLevel;

  List<UserRole> getAllowedRoles() =>
      UserRole.values.where((role) => role.authorityLevel > authorityLevel).toList();

  static List<UserRole> get allSortedByAuthority {
    final roles = UserRole.values.toList()
      ..sort((a, b) => a.authorityLevel.compareTo(b.authorityLevel));
    return roles;
  }

  static UserRole fromAuthorityLevel(int level) {
    switch (level) {
      case 0:
        return UserRole.admin;
      case 1:
        return UserRole.fieldStaff;
      case 2:
        return UserRole.customer;
      default:
        return UserRole.unauthorized;
    }
  }
}
