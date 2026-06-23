import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class AuthUser {
  final String userId;
  final String email;
  final String role;
  final String? displayName;

  const AuthUser({
    required this.userId,
    required this.email,
    required this.role,
    this.displayName,
  });

  bool get isAdmin => role == 'admin';

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        userId: j['user_id'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        displayName: j['display_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'email': email,
        'role': role,
        'display_name': displayName,
      };
}

class AuthService {
  static const _kAccess  = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';
  static const _kUser    = 'auth_user';

  static Future<AuthUser> login(String email, String password) async {
    final res = await apiClient.post(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    return _saveAndReturn(res.data as Map<String, dynamic>);
  }

  static Future<AuthUser> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    final res = await apiClient.post(
      '/api/v1/auth/register',
      data: {
        'email': email,
        'password': password,
        'display_name': displayName,
      },
    );
    return _saveAndReturn(res.data as Map<String, dynamic>);
  }

  static Future<AuthUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUser);
    if (raw == null) return null;
    return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUser);
  }

  static Future<AuthUser> _saveAndReturn(Map<String, dynamic> data) async {
    final user = AuthUser.fromJson(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess,  data['access_token']  as String);
    await prefs.setString(_kRefresh, data['refresh_token'] as String);
    await prefs.setString(_kUser,    jsonEncode(user.toJson()));
    return user;
  }
}
