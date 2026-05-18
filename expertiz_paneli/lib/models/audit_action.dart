/// AUDIT ACTION - Audit Log Action Types
/// 
/// Tüm sistem işlemleri için audit action tanımlamaları
library;

/// Audit Action Enum
enum AuditAction {
  // =====================================================
  // REPORT ACTIONS
  // =====================================================
  
  /// Rapor oluşturuldu
  reportCreated,
  
  /// Rapor güncellendi
  reportUpdated,
  
  /// Rapor silindi
  reportDeleted,
  
  /// Rapor onaylandı
  reportApproved,
  
  /// Rapor reddedildi
  reportRejected,
  
  /// Rapor görüntülendi
  reportViewed,
  
  // =====================================================
  // AI ACTIONS
  // =====================================================
  
  /// AI analizi tetiklendi
  aiAnalysisTriggered,
  
  /// AI analizi tamamlandı
  aiAnalysisCompleted,
  
  /// AI analizi başarısız
  aiAnalysisFailed,
  
  // =====================================================
  // AUTHENTICATION ACTIONS
  // =====================================================
  
  /// Kullanıcı giriş yaptı
  userLogin,
  
  /// Kullanıcı çıkış yaptı
  userLogout,
  
  /// Başarısız giriş denemesi
  loginFailed,
  
  /// Şifre sıfırlama
  passwordReset,
  
  // =====================================================
  // USER MANAGEMENT ACTIONS
  // =====================================================
  
  /// Kullanıcı oluşturuldu
  userCreated,
  
  /// Kullanıcı güncellendi
  userUpdated,
  
  /// Kullanıcı silindi
  userDeleted,
  
  /// Kullanıcı rolü değiştirildi
  userRoleChanged,
  
  /// Kullanıcı izinleri değiştirildi
  userPermissionsChanged,
  
  // =====================================================
  // FINANCIAL ACTIONS
  // =====================================================
  
  /// Ödeme alındı
  paymentReceived,
  
  /// Ödeme iadesi yapıldı
  paymentRefunded,
  
  /// Fatura oluşturuldu
  invoiceCreated,
  
  /// Finansal rapor görüntülendi
  financialReportViewed,
  
  // =====================================================
  // SYSTEM ACTIONS
  // =====================================================
  
  /// Sistem ayarı değiştirildi
  systemSettingChanged,
  
  /// Veri export edildi
  dataExported,
  
  /// Veri import edildi
  dataImported,
  
  /// Batch işlem başlatıldı
  batchOperationStarted,
  
  /// Batch işlem tamamlandı
  batchOperationCompleted,
}

/// Audit Action Extension
extension AuditActionExtension on AuditAction {
  /// Database value
  String get toDatabaseValue {
    switch (this) {
      case AuditAction.reportCreated:
        return 'REPORT_CREATED';
      case AuditAction.reportUpdated:
        return 'REPORT_UPDATED';
      case AuditAction.reportDeleted:
        return 'REPORT_DELETED';
      case AuditAction.reportApproved:
        return 'REPORT_APPROVED';
      case AuditAction.reportRejected:
        return 'REPORT_REJECTED';
      case AuditAction.reportViewed:
        return 'REPORT_VIEWED';
      case AuditAction.aiAnalysisTriggered:
        return 'AI_ANALYSIS_TRIGGERED';
      case AuditAction.aiAnalysisCompleted:
        return 'AI_ANALYSIS_COMPLETED';
      case AuditAction.aiAnalysisFailed:
        return 'AI_ANALYSIS_FAILED';
      case AuditAction.userLogin:
        return 'USER_LOGIN';
      case AuditAction.userLogout:
        return 'USER_LOGOUT';
      case AuditAction.loginFailed:
        return 'LOGIN_FAILED';
      case AuditAction.passwordReset:
        return 'PASSWORD_RESET';
      case AuditAction.userCreated:
        return 'USER_CREATED';
      case AuditAction.userUpdated:
        return 'USER_UPDATED';
      case AuditAction.userDeleted:
        return 'USER_DELETED';
      case AuditAction.userRoleChanged:
        return 'USER_ROLE_CHANGED';
      case AuditAction.userPermissionsChanged:
        return 'USER_PERMISSIONS_CHANGED';
      case AuditAction.paymentReceived:
        return 'PAYMENT_RECEIVED';
      case AuditAction.paymentRefunded:
        return 'PAYMENT_REFUNDED';
      case AuditAction.invoiceCreated:
        return 'INVOICE_CREATED';
      case AuditAction.financialReportViewed:
        return 'FINANCIAL_REPORT_VIEWED';
      case AuditAction.systemSettingChanged:
        return 'SYSTEM_SETTING_CHANGED';
      case AuditAction.dataExported:
        return 'DATA_EXPORTED';
      case AuditAction.dataImported:
        return 'DATA_IMPORTED';
      case AuditAction.batchOperationStarted:
        return 'BATCH_OPERATION_STARTED';
      case AuditAction.batchOperationCompleted:
        return 'BATCH_OPERATION_COMPLETED';
    }
  }

  /// Display name (Turkish)
  String get displayName {
    switch (this) {
      case AuditAction.reportCreated:
        return 'Rapor Oluşturuldu';
      case AuditAction.reportUpdated:
        return 'Rapor Güncellendi';
      case AuditAction.reportDeleted:
        return 'Rapor Silindi';
      case AuditAction.reportApproved:
        return 'Rapor Onaylandı';
      case AuditAction.reportRejected:
        return 'Rapor Reddedildi';
      case AuditAction.reportViewed:
        return 'Rapor Görüntülendi';
      case AuditAction.aiAnalysisTriggered:
        return 'AI Analizi Tetiklendi';
      case AuditAction.aiAnalysisCompleted:
        return 'AI Analizi Tamamlandı';
      case AuditAction.aiAnalysisFailed:
        return 'AI Analizi Başarısız';
      case AuditAction.userLogin:
        return 'Kullanıcı Giriş Yaptı';
      case AuditAction.userLogout:
        return 'Kullanıcı Çıkış Yaptı';
      case AuditAction.loginFailed:
        return 'Başarısız Giriş Denemesi';
      case AuditAction.passwordReset:
        return 'Şifre Sıfırlama';
      case AuditAction.userCreated:
        return 'Kullanıcı Oluşturuldu';
      case AuditAction.userUpdated:
        return 'Kullanıcı Güncellendi';
      case AuditAction.userDeleted:
        return 'Kullanıcı Silindi';
      case AuditAction.userRoleChanged:
        return 'Kullanıcı Rolü Değiştirildi';
      case AuditAction.userPermissionsChanged:
        return 'Kullanıcı İzinleri Değiştirildi';
      case AuditAction.paymentReceived:
        return 'Ödeme Alındı';
      case AuditAction.paymentRefunded:
        return 'Ödeme İadesi Yapıldı';
      case AuditAction.invoiceCreated:
        return 'Fatura Oluşturuldu';
      case AuditAction.financialReportViewed:
        return 'Finansal Rapor Görüntülendi';
      case AuditAction.systemSettingChanged:
        return 'Sistem Ayarı Değiştirildi';
      case AuditAction.dataExported:
        return 'Veri Export Edildi';
      case AuditAction.dataImported:
        return 'Veri Import Edildi';
      case AuditAction.batchOperationStarted:
        return 'Batch İşlem Başlatıldı';
      case AuditAction.batchOperationCompleted:
        return 'Batch İşlem Tamamlandı';
    }
  }

  /// Category for grouping
  String get category {
    switch (this) {
      case AuditAction.reportCreated:
      case AuditAction.reportUpdated:
      case AuditAction.reportDeleted:
      case AuditAction.reportApproved:
      case AuditAction.reportRejected:
      case AuditAction.reportViewed:
        return 'REPORT';
      
      case AuditAction.aiAnalysisTriggered:
      case AuditAction.aiAnalysisCompleted:
      case AuditAction.aiAnalysisFailed:
        return 'AI';
      
      case AuditAction.userLogin:
      case AuditAction.userLogout:
      case AuditAction.loginFailed:
      case AuditAction.passwordReset:
        return 'AUTH';
      
      case AuditAction.userCreated:
      case AuditAction.userUpdated:
      case AuditAction.userDeleted:
      case AuditAction.userRoleChanged:
      case AuditAction.userPermissionsChanged:
        return 'USER';
      
      case AuditAction.paymentReceived:
      case AuditAction.paymentRefunded:
      case AuditAction.invoiceCreated:
      case AuditAction.financialReportViewed:
        return 'FINANCIAL';
      
      case AuditAction.systemSettingChanged:
      case AuditAction.dataExported:
      case AuditAction.dataImported:
      case AuditAction.batchOperationStarted:
      case AuditAction.batchOperationCompleted:
        return 'SYSTEM';
    }
  }

  /// Icon for UI
  String get iconName {
    switch (this) {
      case AuditAction.reportCreated:
      case AuditAction.reportUpdated:
      case AuditAction.reportDeleted:
      case AuditAction.reportApproved:
      case AuditAction.reportRejected:
      case AuditAction.reportViewed:
        return 'description';
      
      case AuditAction.aiAnalysisTriggered:
      case AuditAction.aiAnalysisCompleted:
      case AuditAction.aiAnalysisFailed:
        return 'psychology';
      
      case AuditAction.userLogin:
      case AuditAction.userLogout:
      case AuditAction.loginFailed:
      case AuditAction.passwordReset:
        return 'lock';
      
      case AuditAction.userCreated:
      case AuditAction.userUpdated:
      case AuditAction.userDeleted:
      case AuditAction.userRoleChanged:
      case AuditAction.userPermissionsChanged:
        return 'person';
      
      case AuditAction.paymentReceived:
      case AuditAction.paymentRefunded:
      case AuditAction.invoiceCreated:
      case AuditAction.financialReportViewed:
        return 'payments';
      
      case AuditAction.systemSettingChanged:
      case AuditAction.dataExported:
      case AuditAction.dataImported:
      case AuditAction.batchOperationStarted:
      case AuditAction.batchOperationCompleted:
        return 'settings';
    }
  }

  /// From database value
  static AuditAction fromDatabaseValue(String value) {
    switch (value.toUpperCase()) {
      case 'REPORT_CREATED':
        return AuditAction.reportCreated;
      case 'REPORT_UPDATED':
        return AuditAction.reportUpdated;
      case 'REPORT_DELETED':
        return AuditAction.reportDeleted;
      case 'REPORT_APPROVED':
        return AuditAction.reportApproved;
      case 'REPORT_REJECTED':
        return AuditAction.reportRejected;
      case 'REPORT_VIEWED':
        return AuditAction.reportViewed;
      case 'AI_ANALYSIS_TRIGGERED':
        return AuditAction.aiAnalysisTriggered;
      case 'AI_ANALYSIS_COMPLETED':
        return AuditAction.aiAnalysisCompleted;
      case 'AI_ANALYSIS_FAILED':
        return AuditAction.aiAnalysisFailed;
      case 'USER_LOGIN':
        return AuditAction.userLogin;
      case 'USER_LOGOUT':
        return AuditAction.userLogout;
      case 'LOGIN_FAILED':
        return AuditAction.loginFailed;
      case 'PASSWORD_RESET':
        return AuditAction.passwordReset;
      case 'USER_CREATED':
        return AuditAction.userCreated;
      case 'USER_UPDATED':
        return AuditAction.userUpdated;
      case 'USER_DELETED':
        return AuditAction.userDeleted;
      case 'USER_ROLE_CHANGED':
        return AuditAction.userRoleChanged;
      case 'USER_PERMISSIONS_CHANGED':
        return AuditAction.userPermissionsChanged;
      case 'PAYMENT_RECEIVED':
        return AuditAction.paymentReceived;
      case 'PAYMENT_REFUNDED':
        return AuditAction.paymentRefunded;
      case 'INVOICE_CREATED':
        return AuditAction.invoiceCreated;
      case 'FINANCIAL_REPORT_VIEWED':
        return AuditAction.financialReportViewed;
      case 'SYSTEM_SETTING_CHANGED':
        return AuditAction.systemSettingChanged;
      case 'DATA_EXPORTED':
        return AuditAction.dataExported;
      case 'DATA_IMPORTED':
        return AuditAction.dataImported;
      case 'BATCH_OPERATION_STARTED':
        return AuditAction.batchOperationStarted;
      case 'BATCH_OPERATION_COMPLETED':
        return AuditAction.batchOperationCompleted;
      default:
        return AuditAction.systemSettingChanged;
    }
  }
}