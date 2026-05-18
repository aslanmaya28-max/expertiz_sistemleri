/// ROUTE GUARDS - GoRouter Role-Based Access Control
/// 
/// Route'lara erişim kontrolü ve redirect mantığı
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import 'route_paths.dart';

/// Guard Result
enum GuardResult {
  allowed,
  redirect,
  unauthorized,
}

/// Route Guard
class RouteGuard {
  final UserProvider userProvider;

  RouteGuard({required this.userProvider});

  // =====================================================
  // PUBLIC ROUTES GUARD
  // =====================================================

  /// Check if user can access public routes
  /// 
  /// Redirect logic:
  /// - If logged in, redirect to role-based home
  GuardResult checkPublicRoute() {
    if (userProvider.isAuthenticated) {
      return GuardResult.redirect;
    }
    return GuardResult.allowed;
  }

  /// Get redirect route for authenticated user
  String getRedirectRouteForAuthenticatedUser() {
    if (userProvider.isAdmin) {
      return RoutePaths.admin;
    } else if (userProvider.isFieldStaff) {
      return RoutePaths.personel;
    } else if (userProvider.isCustomer) {
      return RoutePaths.musteri;
    }
    return RoutePaths.login;
  }

  // =====================================================
  // ADMIN ROUTES GUARD
  // =====================================================

  /// Check if user can access admin routes
  GuardResult checkAdminRoute() {
    // Not authenticated
    if (!userProvider.isAuthenticated) {
      debugPrint('🔒 Admin route: Not authenticated');
      return GuardResult.redirect;
    }

    // Not admin
    if (!userProvider.isAdmin) {
      debugPrint('🔒 Admin route: Not admin');
      return GuardResult.unauthorized;
    }

    return GuardResult.allowed;
  }

  // =====================================================
  // PERSONNEL ROUTES GUARD
  // =====================================================

  /// Check if user can access personnel routes
  GuardResult checkPersonelRoute() {
    // Not authenticated
    if (!userProvider.isAuthenticated) {
      debugPrint('🔒 Personel route: Not authenticated');
      return GuardResult.redirect;
    }

    // Not personnel and not admin
    if (!userProvider.isFieldStaff && !userProvider.isAdmin) {
      debugPrint('🔒 Personel route: Not personnel');
      return GuardResult.unauthorized;
    }

    return GuardResult.allowed;
  }

  // =====================================================
  // CUSTOMER ROUTES GUARD
  // =====================================================

  /// Check if user can access customer routes
  GuardResult checkMusteriRoute() {
    // Not authenticated
    if (!userProvider.isAuthenticated) {
      debugPrint('🔒 Musteri route: Not authenticated');
      return GuardResult.redirect;
    }

    // Not customer and not admin
    if (!userProvider.isCustomer && !userProvider.isAdmin) {
      debugPrint('🔒 Musteri route: Not customer');
      return GuardResult.unauthorized;
    }

    return GuardResult.allowed;
  }

  // =====================================================
  // DYNAMIC ROUTES GUARD
  // =====================================================

  /// Check if user can access report routes
  GuardResult checkReportRoute() {
    // Not authenticated
    if (!userProvider.isAuthenticated) {
      debugPrint('🔒 Report route: Not authenticated');
      return GuardResult.redirect;
    }

    // Any authenticated user can view reports
    return GuardResult.allowed;
  }
}

/// GoRouter Redirect Helper
/// 
/// Kullanımı:
/// ```dart
/// GoRouter(
///   redirect: (context, state) {
///     return RouteGuardHelper.redirect(context, state);
///   },
/// )
/// ```
class RouteGuardHelper {
  /// Main redirect function
  static String? redirect(BuildContext context, GoRouterState state) {
    // UserProvider'ı context'ten al
    final userProvider = context.read<UserProvider>();
    final guard = RouteGuard(userProvider: userProvider);

    final path = state.uri.path;

    debugPrint('🔄 Route guard checking: $path');

    // ===================================================
    // PUBLIC ROUTES
    // ===================================================
    
    if (path == RoutePaths.splash || 
        path == RoutePaths.login || 
        path == RoutePaths.register) {
      
      final result = guard.checkPublicRoute();
      
      if (result == GuardResult.redirect) {
        final redirectPath = guard.getRedirectRouteForAuthenticatedUser();
        debugPrint('✅ Redirect authenticated user to: $redirectPath');
        return redirectPath;
      }
      
      return null; // Allow access
    }

    // ===================================================
    // ADMIN ROUTES
    // ===================================================
    
    if (RoutePathsExtension.isAdminRoute(path)) {
      final result = guard.checkAdminRoute();
      
      if (result == GuardResult.redirect) {
        debugPrint('✅ Redirect to login');
        return RoutePaths.login;
      }
      
      if (result == GuardResult.unauthorized) {
        debugPrint('✅ Redirect to unauthorized');
        return RoutePaths.unauthorized;
      }
      
      return null; // Allow access
    }

    // ===================================================
    // PERSONNEL ROUTES
    // ===================================================
    
    if (RoutePathsExtension.isPersonelRoute(path)) {
      final result = guard.checkPersonelRoute();
      
      if (result == GuardResult.redirect) {
        debugPrint('✅ Redirect to login');
        return RoutePaths.login;
      }
      
      if (result == GuardResult.unauthorized) {
        debugPrint('✅ Redirect to unauthorized');
        return RoutePaths.unauthorized;
      }
      
      return null; // Allow access
    }

    // ===================================================
    // CUSTOMER ROUTES
    // ===================================================
    
    if (RoutePathsExtension.isMusteriRoute(path)) {
      final result = guard.checkMusteriRoute();
      
      if (result == GuardResult.redirect) {
        debugPrint('✅ Redirect to login');
        return RoutePaths.login;
      }
      
      if (result == GuardResult.unauthorized) {
        debugPrint('✅ Redirect to unauthorized');
        return RoutePaths.unauthorized;
      }
      
      return null; // Allow access
    }

    // ===================================================
    // REPORT ROUTES (Dynamic)
    // ===================================================
    
    if (path.startsWith('/rapor')) {
      final result = guard.checkReportRoute();
      
      if (result == GuardResult.redirect) {
        debugPrint('✅ Redirect to login');
        return RoutePaths.login;
      }
      
      return null; // Allow access
    }

    // ===================================================
    // OTHER ROUTES - Require authentication
    // ===================================================
    
    if (!userProvider.isAuthenticated) {
      debugPrint('✅ Redirect to login');
      return RoutePaths.login;
    }

    return null; // Allow access
  }

  /// Check if user has specific role
  static bool hasRole(BuildContext context, UserRole role) {
    final userProvider = context.read<UserProvider>();
    return userProvider.currentUser?.role == role;
  }

  /// Check if user is admin
  static bool isAdmin(BuildContext context) {
    return hasRole(context, UserRole.admin);
  }

  /// Check if user is personnel
  static bool isPersonel(BuildContext context) {
    return hasRole(context, UserRole.fieldStaff);
  }

  /// Check if user is customer
  static bool isMusteri(BuildContext context) {
    return hasRole(context, UserRole.customer);
  }

  /// Get user's default route
  static String getDefaultRoute(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    
    if (userProvider.isAdmin) {
      return RoutePaths.admin;
    } else if (userProvider.isFieldStaff) {
      return RoutePaths.personel;
    } else if (userProvider.isCustomer) {
      return RoutePaths.musteri;
    }
    
    return RoutePaths.login;
  }
}
