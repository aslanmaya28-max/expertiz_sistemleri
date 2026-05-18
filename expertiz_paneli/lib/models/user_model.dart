/// USER MODEL - SUPABASE PROFILES TABLOSU
///
/// SINGLE SOURCE OF TRUTH for all user data (admin, field_staff, customer)
/// This model maps directly to Supabase profiles table
library;

import 'package:equatable/equatable.dart';
import '../core/constants/roles.dart';
import '../core/permissions/permission_matrix.dart';

export '../core/constants/roles.dart';

/// User Model - Supabase profiles tablosu
/// 
/// Bu model tüm kullanıcı tiplerini (admin, personel, musteri) 
/// tek bir çatı altında toplar.
class UserModel extends Equatable {
  /// Unique identifier (UUID from Supabase Auth)
  final String id;
  
  /// Email address (from Supabase Auth)
  final String email;
  
  /// Full name
  final String fullName;
  
  /// User role (admin, personel, musteri)
  final UserRole role;
  
  /// Region ID (for personel)
  final int? bolgeId;
  
  /// Province ID (for personel)
  final int? ilId;
  
  /// Phone number
  final String? phone;
  
  /// Profile photo URL
  final String? avatarUrl;
  
  /// Account creation date
  final DateTime createdAt;
  
  /// Last login date
  final DateTime? lastSignInAt;
  
  /// Active status
  final bool isActive;
  
  /// Department (for personel)
  final String? department;
  
  /// Position/Title (for personel)
  final String? position;
  
  /// Expertise area (for personel)
  final String? expertise;
  
  /// Completed task count (for personel)
  final int? completedTaskCount;
  
  /// Average rating (for personel)
  final double? averageRating;
  
  /// Address (for musteri)
  final String? address;
  
  /// City (for musteri)
  final String? city;
  
  /// District (for musteri)
  final String? district;
  
  /// Notes
  final String? notes;
  
  /// Permission Matrix (JSONB from database)
  /// Format: ["report.approve", "user.create", ...]
  final List<String> permissions;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.bolgeId,
    this.ilId,
    this.phone,
    this.avatarUrl,
    required this.createdAt,
    this.lastSignInAt,
    this.isActive = true,
    this.department,
    this.position,
    this.expertise,
    this.completedTaskCount,
    this.averageRating,
    this.address,
    this.city,
    this.district,
    this.notes,
    this.permissions = const [],
  });

  /// Create UserModel from Supabase JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? 
                json['fullName']?.toString() ?? 
                json['ad_soyad']?.toString() ?? '',
      role: UserRole.fromDatabaseValue(
        json['role']?.toString() ?? 
        json['rol']?.toString() ?? 
        'customer'
      ),
      bolgeId: json['bolge_id'] is int 
          ? json['bolge_id'] as int 
          : int.tryParse(json['bolge_id']?.toString() ?? '0'),
      ilId: json['il_id'] is int 
          ? json['il_id'] as int 
          : int.tryParse(json['il_id']?.toString() ?? '0'),
      phone: json['phone']?.toString() ?? json['telefon']?.toString(),
      avatarUrl: json['avatar_url']?.toString() ?? 
                 json['profil_fotograf_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      lastSignInAt: json['last_sign_in_at'] != null
          ? DateTime.parse(json['last_sign_in_at'].toString())
          : null,
      isActive: json['is_active'] as bool? ?? 
                json['aktif'] as bool? ?? true,
      department: json['department']?.toString() ?? 
                  json['departman']?.toString(),
      position: json['position']?.toString() ?? 
                json['unvan']?.toString(),
      expertise: json['expertise']?.toString() ?? 
                 json['uzmanlik_alani']?.toString(),
      completedTaskCount: json['completed_task_count'] is int
          ? json['completed_task_count'] as int
          : int.tryParse(json['completed_task_count']?.toString() ?? '0'),
      averageRating: json['average_rating'] is double
          ? json['average_rating'] as double
          : double.tryParse(json['average_rating']?.toString() ?? '0.0'),
      address: json['address']?.toString() ?? json['adres']?.toString(),
      city: json['city']?.toString() ?? json['il']?.toString(),
      district: json['district']?.toString() ?? json['ilce']?.toString(),
      notes: json['notes']?.toString() ?? json['notlar']?.toString(),
      permissions: json['permissions'] is List
          ? List<String>.from(json['permissions'] as List)
          : PermissionMatrix.getPermissionsForRole(
              json['role']?.toString() ?? json['rol']?.toString() ?? 'musteri'
            ),
    );
  }

  /// Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role.toDatabaseValue,
      'bolge_id': bolgeId,
      'il_id': ilId,
      'phone': phone,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'last_sign_in_at': lastSignInAt?.toIso8601String(),
      'is_active': isActive,
      'department': department,
      'position': position,
      'expertise': expertise,
      'completed_task_count': completedTaskCount,
      'average_rating': averageRating,
      'address': address,
      'city': city,
      'district': district,
      'notes': notes,
      'permissions': permissions,
    };
  }

  /// CopyWith for immutability
  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    int? bolgeId,
    int? ilId,
    String? phone,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? lastSignInAt,
    bool? isActive,
    String? department,
    String? position,
    String? expertise,
    int? completedTaskCount,
    double? averageRating,
    String? address,
    String? city,
    String? district,
    String? notes,
    List<String>? permissions,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      bolgeId: bolgeId ?? this.bolgeId,
      ilId: ilId ?? this.ilId,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      isActive: isActive ?? this.isActive,
      department: department ?? this.department,
      position: position ?? this.position,
      expertise: expertise ?? this.expertise,
      completedTaskCount: completedTaskCount ?? this.completedTaskCount,
      averageRating: averageRating ?? this.averageRating,
      address: address ?? this.address,
      city: city ?? this.city,
      district: district ?? this.district,
      notes: notes ?? this.notes,
      permissions: permissions ?? this.permissions,
    );
  }

  // =====================================================
  // CONVENIENCE GETTERS (NEW ROLE NAMES)
  // =====================================================

  /// Is this user an admin?
  bool get isAdmin => role == UserRole.admin;
   
  bool get isFieldStaff => role == UserRole.fieldStaff;
   
  bool get isCustomer => role == UserRole.customer;

  bool get isUnauthorized => role == UserRole.unauthorized;

  bool get isPersonel => isFieldStaff;

  bool get isMusteri => isCustomer;

  /// Get initials for avatar
  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  /// Display name with role
  String get displayName => '$fullName (${role.displayName})';

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, fullName: $fullName, role: $role)';
  }

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        role,
        bolgeId,
        ilId,
        phone,
        avatarUrl,
        createdAt,
        lastSignInAt,
        isActive,
        department,
        position,
        expertise,
        completedTaskCount,
        averageRating,
        address,
        city,
        district,
        notes,
        permissions,
      ];
}
