import 'package:dio/dio.dart';
import '../config/api_config.dart';

final Dio apiClient = Dio(
  BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Accept': 'application/json'},
  ),
);
