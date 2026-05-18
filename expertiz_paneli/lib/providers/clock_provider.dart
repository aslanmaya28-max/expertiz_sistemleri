import 'package:flutter/material.dart';

// Basit clock provider - şimdilik sadece placeholder
class ClockProvider with ChangeNotifier {
  DateTime _currentTime = DateTime.now();

  DateTime get currentTime => _currentTime;

  void updateTime() {
    _currentTime = DateTime.now();
    notifyListeners();
  }
}
