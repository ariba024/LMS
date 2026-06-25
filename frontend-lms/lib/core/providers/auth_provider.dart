import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart' show onAuthExpired;
import '../services/auth_service.dart';

// Testing bypass — set to false to re-enable real login
const bool _kDevAuthBypass = true;

class AuthState {
  final AuthUser? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  void _init() async {
    // Wire forced-logout callback from the Dio interceptor
    onAuthExpired = () {
      if (!_kDevAuthBypass && mounted) state = const AuthState();
    };
    if (_kDevAuthBypass) {
      state = AuthState(
        user: const AuthUser(
          userId: 'dev-admin',
          email: 'dev@arresto.in',
          role: 'admin',
          displayName: 'Dev Admin',
        ),
      );
      return;
    }
    final user = await AuthService.restoreSession();
    if (mounted) state = AuthState(user: user);
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await AuthService.login(email, password);
      state = AuthState(user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> register(String email, String password, {String? displayName}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await AuthService.register(email, password, displayName: displayName);
      state = AuthState(user: user);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _msg(e));
    }
  }

  Future<void> logout() async {
    await AuthService.logout();
    state = const AuthState();
  }

  String _msg(Object e) {
    final s = e.toString();
    if (s.contains('401') || s.contains('Invalid')) return 'Invalid email or password.';
    if (s.contains('409') || s.contains('already')) return 'Email already registered.';
    return 'Something went wrong. Please try again.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
