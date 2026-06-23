import 'api_client.dart';

class AdminUser {
  final String  id;
  final String  email;
  final String  role;
  final String? displayName;
  final bool    isActive;
  final double  createdAt;

  const AdminUser({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
    required this.isActive,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';
  String get name => displayName ?? email.split('@').first;

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id:          j['id']           as String,
        email:       j['email']        as String,
        role:        j['role']         as String,
        displayName: j['display_name'] as String?,
        isActive:    j['is_active']    as bool,
        createdAt:   (j['created_at']  as num).toDouble(),
      );
}

class AdminUserService {
  static Future<List<AdminUser>> listUsers() async {
    final resp = await apiClient.get('/api/v1/admin/users');
    return (resp.data as List)
        .map((j) => AdminUser.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<AdminUser> createUser({
    required String email,
    required String password,
    required String role,
    String? displayName,
  }) async {
    final resp = await apiClient.post('/api/v1/admin/users', data: {
      'email':    email,
      'password': password,
      'role':     role,
      if (displayName != null && displayName.isNotEmpty)
        'display_name': displayName,
    });
    return AdminUser.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<AdminUser> updateUser(
    String id, {
    String? role,
    String? displayName,
    bool?   isActive,
  }) async {
    final resp = await apiClient.patch('/api/v1/admin/users/$id', data: {
      if (role        != null) 'role':         role,
      if (displayName != null) 'display_name': displayName,
      if (isActive    != null) 'is_active':    isActive,
    });
    return AdminUser.fromJson(resp.data as Map<String, dynamic>);
  }

  static Future<void> resetPassword(String id, String newPassword) async {
    await apiClient.post(
      '/api/v1/admin/users/$id/reset-password',
      data: {'new_password': newPassword},
    );
  }

  static Future<void> deactivateUser(String id) async {
    await apiClient.delete('/api/v1/admin/users/$id');
  }

  static Future<void> changePassword(
      String currentPassword, String newPassword) async {
    await apiClient.post('/api/v1/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password':     newPassword,
    });
  }
}
