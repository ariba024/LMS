import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

const _kAccessKey  = 'auth_access_token';
const _kRefreshKey = 'auth_refresh_token';
const _kUserKey    = 'auth_user';

class AuthUser {
  final String  userId;
  final String  email;
  final String  role;
  final String? displayName;

  const AuthUser({
    required this.userId,
    required this.email,
    required this.role,
    this.displayName,
  });

  bool get isAdmin => role == 'admin';

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        userId:      j['user_id']      as String,
        email:       j['email']        as String,
        role:        j['role']         as String,
        displayName: j['display_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'user_id':      userId,
        'email':        email,
        'role':         role,
        'display_name': displayName,
      };
}

/// Broadcast stream that fires whenever a token refresh fails and the session
/// must be terminated (interceptor → AuthNotifier).
final _forcedLogoutCtrl = StreamController<void>.broadcast();

class AuthService {
  static Stream<void> get onForcedLogout => _forcedLogoutCtrl.stream;

  /// Called by the Dio interceptor when token refresh fails.
  static void signalForcedLogout() => _forcedLogoutCtrl.add(null);

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
  ));

  Future<AuthUser> login(String email, String password) async {
    final resp = await _dio.post('/api/v1/auth/login', data: {
      'email':    email,
      'password': password,
    });
    return _persist(resp.data as Map<String, dynamic>);
  }

  Future<AuthUser> register(
      String email, String password, String? displayName) async {
    final resp = await _dio.post('/api/v1/auth/register', data: {
      'email':    email,
      'password': password,
      if (displayName != null && displayName.isNotEmpty)
        'display_name': displayName,
    });
    return _persist(resp.data as Map<String, dynamic>);
  }

  /// Try to restore session from stored tokens. Returns null if no valid session.
  Future<AuthUser?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson     = prefs.getString(_kUserKey);
    final refreshToken = prefs.getString(_kRefreshKey);
    if (userJson == null || refreshToken == null) return null;
    try {
      final resp = await _dio.post('/api/v1/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      return _persist(resp.data as Map<String, dynamic>);
    } catch (_) {
      await _clearStorage(prefs);
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearStorage(prefs);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccessKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefreshKey);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<AuthUser> _persist(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessKey,  data['access_token']  as String);
    await prefs.setString(_kRefreshKey, data['refresh_token'] as String);
    final user = AuthUser.fromJson(data);
    await prefs.setString(_kUserKey, jsonEncode(user.toJson()));
    return user;
  }

  static Future<void> _clearStorage(SharedPreferences prefs) async {
    await prefs.remove(_kAccessKey);
    await prefs.remove(_kRefreshKey);
    await prefs.remove(_kUserKey);
  }
}
