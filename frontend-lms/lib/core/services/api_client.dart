import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'auth_service.dart';

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final prefs         = await SharedPreferences.getInstance();
      final refreshToken  = prefs.getString('auth_refresh_token');
      if (refreshToken != null) {
        try {
          final refreshDio = Dio(BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ));
          final resp = await refreshDio.post(
            '/api/v1/auth/refresh',
            data: {'refresh_token': refreshToken},
          );
          final data        = resp.data as Map<String, dynamic>;
          final newAccess   = data['access_token']  as String;
          final newRefresh  = data['refresh_token'] as String;
          await prefs.setString('auth_access_token',  newAccess);
          await prefs.setString('auth_refresh_token', newRefresh);

          // Retry the original request with the new token
          final retryOptions = err.requestOptions
            ..headers['Authorization'] = 'Bearer $newAccess';
          final response = await apiClient.fetch(retryOptions);
          handler.resolve(response);
          return;
        } catch (_) {
          // Refresh failed — force logout
          await prefs.remove('auth_access_token');
          await prefs.remove('auth_refresh_token');
          await prefs.remove('auth_user');
          AuthService.signalForcedLogout();
        }
      }
    }
    handler.next(err);
  }
}

final Dio apiClient = Dio(
  BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Accept': 'application/json'},
  ),
)..interceptors.add(_AuthInterceptor());
