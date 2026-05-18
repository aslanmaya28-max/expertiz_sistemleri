import '../exceptions/access_denied_exception.dart';
import '../../models/user_model.dart';

class AccessPolicy {
  AccessPolicy._();

  static void _denyUnauthorized(UserModel currentUser, String operation) {
    if (currentUser.role == UserRole.unauthorized) {
      throw AccessDeniedException(
        message: 'Yetkisiz erişim',
        operation: operation,
        userRole: currentUser.role.displayName,
        errorCode: 'UNAUTHORIZED',
      );
    }
  }

  static void canAddPersonel(
    UserModel currentUser,
    int targetIlId,
    int targetBolgeId,
  ) {
    _denyUnauthorized(currentUser, 'personel_ekle');

    if (currentUser.role == UserRole.admin) {
      return;
    }

    throw AccessDeniedException(
      message: 'Personel eklemek için yetkiniz yok',
      operation: 'personel_ekle',
      userRole: currentUser.role.displayName,
      errorCode: 'INSUFFICIENT_PERMISSION',
    );
  }

  static void canUpdatePersonel(
    UserModel currentUser,
    String targetPersonelId,
  ) {
    _denyUnauthorized(currentUser, 'personel_guncelle');

    if (currentUser.role == UserRole.admin) {
      return;
    }

    if (currentUser.role == UserRole.fieldStaff) {
      if (currentUser.id != targetPersonelId) {
        throw AccessDeniedException(
          message: 'Sadece kendi bilgilerinizi güncelleyebilirsiniz',
          operation: 'personel_guncelle',
          userRole: currentUser.role.displayName,
          errorCode: 'SELF_ONLY',
        );
      }
      return;
    }

    throw AccessDeniedException(
      message: 'Personel güncelleme yetkiniz yok',
      operation: 'personel_guncelle',
      userRole: currentUser.role.displayName,
      errorCode: 'INSUFFICIENT_PERMISSION',
    );
  }

  static void canDeletePersonel(
    UserModel currentUser,
    String targetPersonelId,
  ) {
    _denyUnauthorized(currentUser, 'personel_sil');

    if (currentUser.role == UserRole.admin) {
      return;
    }

    if (currentUser.role == UserRole.fieldStaff) {
      if (currentUser.id != targetPersonelId) {
        throw AccessDeniedException(
          message: 'Sadece kendi hesabınızı silebilirsiniz',
          operation: 'personel_sil',
          userRole: currentUser.role.displayName,
          errorCode: 'SELF_ONLY',
        );
      }
      return;
    }

    throw AccessDeniedException(
      message: 'Personel silme yetkiniz yok',
      operation: 'personel_sil',
      userRole: currentUser.role.displayName,
      errorCode: 'INSUFFICIENT_PERMISSION',
    );
  }

  static void canViewReport(
    UserModel currentUser,
    int reportIlId,
    String? reportOwnerId,
  ) {
    _denyUnauthorized(currentUser, 'rapor_goruntule');

    if (currentUser.role == UserRole.admin) {
      return;
    }

    if (currentUser.role == UserRole.fieldStaff) {
      if (currentUser.ilId != reportIlId) {
        throw AccessDeniedException(
          message: 'Sadece kendi şehrinizdeki raporları görüntüleyebilirsiniz',
          operation: 'rapor_goruntule',
          userRole: currentUser.role.displayName,
          errorCode: 'REGION_MISMATCH',
        );
      }
      return;
    }

    if (currentUser.role == UserRole.customer) {
      if (reportOwnerId == null || currentUser.id != reportOwnerId) {
        throw AccessDeniedException(
          message: 'Sadece kendi raporlarınızı görüntüleyebilirsiniz',
          operation: 'rapor_goruntule',
          userRole: currentUser.role.displayName,
          errorCode: 'OWNER_ONLY',
        );
      }
      return;
    }
  }

  static void canCreateReport(UserModel currentUser) {
    _denyUnauthorized(currentUser, 'rapor_olustur');
  }

  static void canDeleteReport(
    UserModel currentUser,
    int reportIlId,
    String? reportOwnerId,
  ) {
    _denyUnauthorized(currentUser, 'rapor_sil');

    if (currentUser.role == UserRole.admin) {
      return;
    }

    if (currentUser.role == UserRole.fieldStaff) {
      if (currentUser.ilId != reportIlId) {
        throw AccessDeniedException(
          message: 'Sadece kendi şehrinizdeki raporları silebilirsiniz',
          operation: 'rapor_sil',
          userRole: currentUser.role.displayName,
          errorCode: 'REGION_MISMATCH',
        );
      }
      return;
    }

    if (currentUser.role == UserRole.customer) {
      if (reportOwnerId == null || currentUser.id != reportOwnerId) {
        throw AccessDeniedException(
          message: 'Sadece kendi raporlarınızı silebilirsiniz',
          operation: 'rapor_sil',
          userRole: currentUser.role.displayName,
          errorCode: 'OWNER_ONLY',
        );
      }
      return;
    }
  }
}
