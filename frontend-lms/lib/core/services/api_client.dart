import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

// Registered by AuthNotifier._init() to avoid circular import
void Function()? onAuthExpired;

final Dio apiClient = Dio(
  BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Accept': 'application/json'},
  ),
)..interceptors.add(_AuthInterceptor());

class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_access_token');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('auth_refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      _clearAndSignal(prefs);
      handler.next(err);
      return;
    }

    try {
      // Use a fresh Dio instance to avoid re-triggering this interceptor
      final refreshDio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final res = await refreshDio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newAccess  = res.data['access_token']  as String;
      final newRefresh = res.data['refresh_token'] as String;
      await prefs.setString('auth_access_token',  newAccess);
      await prefs.setString('auth_refresh_token', newRefresh);

      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccess';
      final retried = await apiClient.fetch(opts);
      handler.resolve(retried);
    } catch (_) {
      _clearAndSignal(prefs);
      handler.next(err);
    }
  }

  void _clearAndSignal(SharedPreferences prefs) {
    prefs.remove('auth_access_token');
    prefs.remove('auth_refresh_token');
    prefs.remove('auth_user');
    onAuthExpired?.call();
  }
}
