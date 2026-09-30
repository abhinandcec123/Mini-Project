import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// Holds the active session (token, role, user payload) for exactly one
/// role at a time — mirrors the original app's route-guard rule that a
/// user can't jump across donor/hospital/admin views without logging out.
class AuthProvider extends ChangeNotifier {
  String? _token;
  String? _role; // 'donor' | 'hospital' | 'admin'
  Map<String, dynamic>? _user;
  bool _restoring = true;

  String? get token => _token;
  String? get role => _role;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get isRestoring => _restoring;

  ApiService get api => ApiService(token: _token);

  AuthProvider() {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('lp_token');
    _role = prefs.getString('lp_role');
    _restoring = false;
    notifyListeners();
  }

  Future<void> setSession(String token, String role, Map<String, dynamic> user) async {
    _token = token;
    _role = role;
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lp_token', token);
    await prefs.setString('lp_role', role);
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> user) {
    _user = user;
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _role = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lp_token');
    await prefs.remove('lp_role');
    notifyListeners();
  }
}
