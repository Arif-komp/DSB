// lib/user_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  String? _activeUser;

  String? get activeUser => _activeUser;

  UserProvider() {
    _loadActiveUser();
  }

  Future<void> _loadActiveUser() async {
    final prefs = await SharedPreferences.getInstance();
    _activeUser = prefs.getString('activeUser');
    notifyListeners();
  }

  // Menggantikan logika login di index.html/script.js
  Future<bool> login(String username) async {
    if (username.trim().isEmpty) return false;
    
    final prefs = await SharedPreferences.getInstance();
    _activeUser = username.toUpperCase();
    await prefs.setString('activeUser', _activeUser!);
    notifyListeners();
    return true;
  }

  // Menggantikan fungsi JS: handleLogout()
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('activeUser');
    _activeUser = null;
    notifyListeners();
  }
}
