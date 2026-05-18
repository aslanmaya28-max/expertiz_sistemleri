import 'package:flutter/material.dart';

class AppMenuController extends ChangeNotifier {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _currentRole = 'admin'; // 'admin', 'personel', 'musteri'
  
  GlobalKey<ScaffoldState> get scaffoldKey => _scaffoldKey;
  String get currentRole => _currentRole;
  
  void controlMenu() {
    if (!_scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.openDrawer();
    }
  }
  
  void setRole(String role) {
    _currentRole = role;
    notifyListeners();
  }
}