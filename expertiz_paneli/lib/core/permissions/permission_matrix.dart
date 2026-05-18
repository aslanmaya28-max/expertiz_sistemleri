/// PERMISSION MATRIX - RBAC Permission Definitions
/// 
/// Role-Based Access Control için izin tanımlamaları
library;

/// Permission Matrix
/// 
/// Tüm sistem izinleri burada tanımlanır
/// Format: entity.action (örn: report.approve, user.create)
class PermissionMatrix {
  // =====================================================
  // REPORT PERMISSIONS
  // =====================================================
  
  /// Rapor oluşturabilir
  static const String reportCreate = 'report.create';
  
  /// Rapor görüntüleyebilir
  static const String reportView = 'report.view';
  
  /// Rapor düzenleyebilir
  static const String reportUpdate = 'report.update';
  
  /// Rapor silebilir
  static const String reportDelete = 'report.delete';
  
  /// Rapor onaylayabilir
  static const String reportApprove = 'report.approve';
  
  /// Rapor reddedebilir
  static const String reportReject = 'report.reject';
  
  /// Tüm raporları görüntüleyebilir
  static const String reportViewAll = 'report.view_all';
  
  // =====================================================
  // AI PERMISSIONS
  // =====================================================
  
  /// AI analizini tetikleyebilir
  static const String aiTrigger = 'ai.trigger';
  
  /// AI analiz sonucunu görüntüleyebilir
  static const String aiView = 'ai.view';
  
  /// AI analiz ayarlarını değiştirebilir
  static const String aiSettings = 'ai.settings';
  
  // =====================================================
  // USER PERMISSIONS
  // =====================================================
  
  /// Kullanıcı oluşturabilir
  static const String userCreate = 'user.create';
  
  /// Kullanıcı görüntüleyebilir
  static const String userView = 'user.view';
  
  /// Kullanıcı düzenleyebilir
  static const String userUpdate = 'user.update';
  
  /// Kullanıcı silebilir
  static const String userDelete = 'user.delete';
  
  /// Kullanıcı rolünü değiştirebilir
  static const String userChangeRole = 'user.change_role';
  
  /// Kullanıcı izinlerini değiştirebilir
  static const String userChangePermissions = 'user.change_permissions';
  
  /// Tüm kullanıcıları görüntüleyebilir
  static const String userViewAll = 'user.view_all';
  
  // =====================================================
  // FINANCIAL PERMISSIONS
  // =====================================================
  
  /// Finansal raporları görüntüleyebilir
  static const String financialView = 'financial.view';
  
  /// Ödeme alabilir
  static const String paymentReceive = 'payment.receive';
  
  /// Ödeme iadesi yapabilir
  static const String paymentRefund = 'payment.refund';
  
  /// Fatura oluşturabilir
  static const String invoiceCreate = 'invoice.create';
  
  /// Fatura görüntüleyebilir
  static const String invoiceView = 'invoice.view';
  
  /// Finansal ayarları değiştirebilir
  static const String financialSettings = 'financial.settings';
  
  // =====================================================
  // SYSTEM PERMISSIONS
  // =====================================================
  
  /// Sistem ayarlarını görüntüleyebilir
  static const String settingsView = 'settings.view';
  
  /// Sistem ayarlarını değiştirebilir
  static const String settingsUpdate = 'settings.update';
  
  /// Audit logları görüntüleyebilir
  static const String auditLogView = 'audit_log.view';
  
  /// Veri export edebilir
  static const String dataExport = 'data.export';
  
  /// Veri import edebilir
  static const String dataImport = 'data.import';
  
  /// Batch işlem başlatabilir
  static const String batchOperation = 'batch.operation';
  
  // =====================================================
  // ROLE-BASED PERMISSIONS
  // =====================================================
  
  /// Admin izinleri (tüm izinler)
  static const List<String> adminPermissions = [
    // Report permissions
    reportCreate,
    reportView,
    reportUpdate,
    reportDelete,
    reportApprove,
    reportReject,
    reportViewAll,
    
    // AI permissions
    aiTrigger,
    aiView,
    aiSettings,
    
    // User permissions
    userCreate,
    userView,
    userUpdate,
    userDelete,
    userChangeRole,
    userChangePermissions,
    userViewAll,
    
    // Financial permissions
    financialView,
    paymentReceive,
    paymentRefund,
    invoiceCreate,
    invoiceView,
    financialSettings,
    
    // System permissions
    settingsView,
    settingsUpdate,
    auditLogView,
    dataExport,
    dataImport,
    batchOperation,
  ];
  
  /// Personel izinleri
  static const List<String> personelPermissions = [
    // Report permissions
    reportCreate,
    reportView,
    reportUpdate,
    reportViewAll,
    
    // AI permissions
    aiTrigger,
    aiView,
    
    // Financial permissions (limited)
    invoiceView,
    
    // System permissions (limited)
    dataExport,
  ];
  
  /// Müşteri izinleri
  static const List<String> musteriPermissions = [
    // Report permissions (own only)
    reportView,
    
    // Financial permissions (own only)
    invoiceView,
  ];
  
  // =====================================================
  // HELPER METHODS
  // =====================================================
  
  /// Role göre izinleri getir
  static List<String> getPermissionsForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return adminPermissions;
      case 'field_staff':
      case 'personel':
        return personelPermissions;
      case 'customer':
      case 'musteri':
        return musteriPermissions;
      default:
        return [];
    }
  }
  
  /// İzin listesi kontrolü (en az biri var mı?)
  static bool hasAnyPermission(
    List<String> userPermissions,
    List<String> requiredPermissions,
  ) {
    return userPermissions.any((p) => requiredPermissions.contains(p));
  }
  
  /// İzin listesi kontrolü (hepsi var mı?)
  static bool hasAllPermissions(
    List<String> userPermissions,
    List<String> requiredPermissions,
  ) {
    return requiredPermissions.every((p) => userPermissions.contains(p));
  }
  
  /// Tek izin kontrolü
  static bool hasPermission(
    List<String> userPermissions,
    String permission,
  ) {
    return userPermissions.contains(permission);
  }
  
  /// İzin açıklamasını getir (Turkish)
  static String getPermissionDescription(String permission) {
    switch (permission) {
      // Report permissions
      case reportCreate:
        return 'Rapor oluşturabilir';
      case reportView:
        return 'Rapor görüntüleyebilir';
      case reportUpdate:
        return 'Rapor düzenleyebilir';
      case reportDelete:
        return 'Rapor silebilir';
      case reportApprove:
        return 'Rapor onaylayabilir';
      case reportReject:
        return 'Rapor reddedebilir';
      case reportViewAll:
        return 'Tüm raporları görüntüleyebilir';
      
      // AI permissions
      case aiTrigger:
        return 'AI analizini tetikleyebilir';
      case aiView:
        return 'AI analiz sonucunu görüntüleyebilir';
      case aiSettings:
        return 'AI analiz ayarlarını değiştirebilir';
      
      // User permissions
      case userCreate:
        return 'Kullanıcı oluşturabilir';
      case userView:
        return 'Kullanıcı görüntüleyebilir';
      case userUpdate:
        return 'Kullanıcı düzenleyebilir';
      case userDelete:
        return 'Kullanıcı silebilir';
      case userChangeRole:
        return 'Kullanıcı rolünü değiştirebilir';
      case userChangePermissions:
        return 'Kullanıcı izinlerini değiştirebilir';
      case userViewAll:
        return 'Tüm kullanıcıları görüntüleyebilir';
      
      // Financial permissions
      case financialView:
        return 'Finansal raporları görüntüleyebilir';
      case paymentReceive:
        return 'Ödeme alabilir';
      case paymentRefund:
        return 'Ödeme iadesi yapabilir';
      case invoiceCreate:
        return 'Fatura oluşturabilir';
      case invoiceView:
        return 'Fatura görüntüleyebilir';
      case financialSettings:
        return 'Finansal ayarları değiştirebilir';
      
      // System permissions
      case settingsView:
        return 'Sistem ayarlarını görüntüleyebilir';
      case settingsUpdate:
        return 'Sistem ayarlarını değiştirebilir';
      case auditLogView:
        return 'Audit logları görüntüleyebilir';
      case dataExport:
        return 'Veri export edebilir';
      case dataImport:
        return 'Veri import edebilir';
      case batchOperation:
        return 'Batch işlem başlatabilir';
      
      default:
        return 'Bilinmeyen izin';
    }
  }
  
  /// İzin kategorisini getir
  static String getPermissionCategory(String permission) {
    if (permission.startsWith('report.')) return 'Rapor';
    if (permission.startsWith('ai.')) return 'Yapay Zeka';
    if (permission.startsWith('user.')) return 'Kullanıcı Yönetimi';
    if (permission.startsWith('payment.') || permission.startsWith('invoice.') || permission.startsWith('financial.')) return 'Finans';
    if (permission.startsWith('settings.') || permission.startsWith('audit_log.') || permission.startsWith('data.') || permission.startsWith('batch.')) return 'Sistem';
    return 'Diğer';
  }
  
  /// Kategorideki tüm izinleri getir
  static List<String> getPermissionsByCategory(String category) {
    switch (category.toLowerCase()) {
      case 'rapor':
        return [
          reportCreate,
          reportView,
          reportUpdate,
          reportDelete,
          reportApprove,
          reportReject,
          reportViewAll,
        ];
      case 'yapay zeka':
        return [
          aiTrigger,
          aiView,
          aiSettings,
        ];
      case 'kullanıcı yönetimi':
        return [
          userCreate,
          userView,
          userUpdate,
          userDelete,
          userChangeRole,
          userChangePermissions,
          userViewAll,
        ];
      case 'finans':
        return [
          financialView,
          paymentReceive,
          paymentRefund,
          invoiceCreate,
          invoiceView,
          financialSettings,
        ];
      case 'sistem':
        return [
          settingsView,
          settingsUpdate,
          auditLogView,
          dataExport,
          dataImport,
          batchOperation,
        ];
      default:
        return [];
    }
  }
  
  /// Tüm izinleri getir
  static List<String> getAllPermissions() {
    return [
      ...getPermissionsByCategory('rapor'),
      ...getPermissionsByCategory('yapay zeka'),
      ...getPermissionsByCategory('kullanıcı yönetimi'),
      ...getPermissionsByCategory('finans'),
      ...getPermissionsByCategory('sistem'),
    ];
  }
}