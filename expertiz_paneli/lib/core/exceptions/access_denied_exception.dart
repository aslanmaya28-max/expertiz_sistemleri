import 'package:flutter/foundation.dart';

/// Yetkisiz erişim istisnası
/// 
/// Kullanıcının belirli bir işlemi gerçekleştirmek için gerekli yetkiye sahip olmadığı
/// durumlarda fırlatılır. Bu istisna, güvenlik açısından kritik bir rol oynar ve
/// tüm write işlemlerinde kontrol edilmelidir.
class AccessDeniedException implements Exception {
  /// Hata mesajı
  final String message;
  
  /// İşlem türü (örn: 'personel_ekle', 'personel_sil')
  final String? operation;
  
  /// Kullanıcının rolü
  final String? userRole;
  
  /// Gerekli rol
  final String? requiredRole;
  
  /// Erişilmeye çalışılan kaynak (örn: 'il_id: 123', 'bolge_id: 456')
  final String? resource;
  
  /// Hata kodu
  final String errorCode;

  const AccessDeniedException({
    required this.message,
    this.operation,
    this.userRole,
    this.requiredRole,
    this.resource,
    this.errorCode = 'ACCESS_DENIED',
  });

  @override
  String toString() {
    final buffer = StringBuffer('AccessDeniedException: $message');
    
    if (operation != null) buffer.write(' | İşlem: $operation');
    if (userRole != null) buffer.write(' | Kullanıcı Rolü: $userRole');
    if (requiredRole != null) buffer.write(' | Gerekli Rol: $requiredRole');
    if (resource != null) buffer.write(' | Kaynak: $resource');
    buffer.write(' | Kod: $errorCode');
    
    return buffer.toString();
  }

  /// Kullanıcıya gösterilebilir kullanıcı dostu mesaj
  String get userMessage {
    switch (errorCode) {
      case 'INSUFFICIENT_ROLE':
        return 'Bu işlemi gerçekleştirmek için yeterli yetkiniz yok. Lütfen sistem yöneticisi ile iletişime geçin.';
      case 'REGION_MISMATCH':
        return 'Bu işlem sadece yetkili bölgenizde gerçekleştirilebilir.';
      case 'CITY_MISMATCH':
        return 'Bu işlem sadece yetkili şehrinizde gerçekleştirilebilir.';
      case 'ADMIN_ONLY':
        return 'Bu işlem sadece sistem yöneticileri tarafından gerçekleştirilebilir.';
      default:
        return 'Bu işlemi gerçekleştirmek için yetkiniz yok.';
    }
  }

  /// Debug log için detaylı bilgi
  void logDebug() {
    debugPrint('=== ACCESS DENIED ===');
    debugPrint('Message: $message');
    debugPrint('Operation: $operation');
    debugPrint('User Role: $userRole');
    debugPrint('Required Role: $requiredRole');
    debugPrint('Resource: $resource');
    debugPrint('Error Code: $errorCode');
    debugPrint('====================');
  }

  /// Factory method: Rol yetmezliği hatası
  factory AccessDeniedException.insufficientRole({
    required String operation,
    required String userRole,
    required String requiredRole,
  }) {
    return AccessDeniedException(
      message: 'Kullanıcının rolü yetersiz',
      operation: operation,
      userRole: userRole,
      requiredRole: requiredRole,
      errorCode: 'INSUFFICIENT_ROLE',
    );
  }

  /// Factory method: Bölge uyuşmazlığı hatası
  factory AccessDeniedException.regionMismatch({
    required String operation,
    required String userRegionId,
    required String targetRegionId,
  }) {
    return AccessDeniedException(
      message: 'Kullanıcı bu bölgeye yetkili değil',
      operation: operation,
      resource: 'user_bolge_id: $userRegionId, target_bolge_id: $targetRegionId',
      errorCode: 'REGION_MISMATCH',
    );
  }

  /// Factory method: Şehir uyuşmazlığı hatası
  factory AccessDeniedException.cityMismatch({
    required String operation,
    required String userCityId,
    required String targetCityId,
  }) {
    return AccessDeniedException(
      message: 'Kullanıcı bu şehre yetkili değil',
      operation: operation,
      resource: 'user_il_id: $userCityId, target_il_id: $targetCityId',
      errorCode: 'CITY_MISMATCH',
    );
  }

  /// Factory method: Admin-only işlem hatası
  factory AccessDeniedException.adminOnly({
    required String operation,
    required String userRole,
  }) {
    return AccessDeniedException(
      message: 'Bu işlem sadece adminler tarafından yapılabilir',
      operation: operation,
      userRole: userRole,
      requiredRole: 'admin',
      errorCode: 'ADMIN_ONLY',
    );
  }
}
