import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

/// Holds the active session (token, role, user payload) for exactly one
/// role at a time — mirrors the original app's route-guard rule that a
/// user can't jump across donor/hospital/admin views without logging out.
class AuthProvider extends ChangeNotifier {
  static const _tokenKey = 'lp_token';
  static const _roleKey = 'lp_role';
  static const _passwordChangeKey = 'lp_password_change_required';
  static const _secureTokenKey = 'lp_token';
  static const _secureStorage = FlutterSecureStorage();

  String? _token;
  String? _role; // 'donor' | 'hospital' | 'admin'
  Map<String, dynamic>? _user;
  bool _passwordChangeRequired = false;
  bool _restoring = true;

  String? get token => _token;
  String? get role => _role;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get passwordChangeRequired => _passwordChangeRequired;
  bool get isRestoring => _restoring;

  ApiService get api => ApiService(token: _token, onUnauthorized: logout);

  AuthProvider() {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _role = prefs.getString(_roleKey);
      _passwordChangeRequired = prefs.getBool(_passwordChangeKey) ?? false;

      var secureReadFailed = false;
      try {
        _token = await _secureStorage.read(key: _secureTokenKey);
      } on Exception {
        secureReadFailed = true;
      }
      if (_token == null) {
        // Migrate the existing token only after the secure write succeeds.
        // If secure storage is temporarily unavailable, keep the old value
        // for a later retry and retain it in memory for this running session.
        final legacyToken = prefs.getString(_tokenKey);
        if (legacyToken != null) {
          _token = legacyToken;
          if (!secureReadFailed) {
            try {
              await _secureStorage.write(
                  key: _secureTokenKey, value: legacyToken);
              await prefs.remove(_tokenKey);
            } on Exception {
              // Leave legacy storage intact rather than lose the existing session.
            }
          }
        }
      } else {
        await prefs.remove(_tokenKey);
      }
    } on Exception {
      // Always finish restoration so a storage/plugin error cannot leave the
      // application on an endless loading screen.
      _token = null;
      _role = null;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> setSession(
    String token,
    String role,
    Map<String, dynamic> user, {
    bool passwordChangeRequired = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: _secureTokenKey, value: token);
    await prefs.setString(_roleKey, role);
    await prefs.setBool(_passwordChangeKey, passwordChangeRequired);
    await prefs.remove(_tokenKey);
    _token = token;
    _role = role;
    _user = user;
    _passwordChangeRequired = passwordChangeRequired;
    notifyListeners();
  }

  void updateUser(Map<String, dynamic> user) {
    _user = user;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await _secureStorage.delete(key: _secureTokenKey);
    } finally {
      await prefs.remove(_tokenKey);
      await prefs.remove(_roleKey);
      await prefs.remove(_passwordChangeKey);
      _token = null;
      _role = null;
      _user = null;
      _passwordChangeRequired = false;
      notifyListeners();
    }
  }
}
