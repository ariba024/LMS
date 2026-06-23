import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

export '../services/auth_service.dart' show AuthUser;

// ── State ─────────────────────────────────────────────────────────────────────

class AuthState {
  final AuthUser? user;
  final bool      isLoading;
  final String?   error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool?     isLoading,
    String?   error,
    bool      clearUser  = false,
    bool      clearError = false,
  }) =>
      AuthState(
        user:      clearUser  ? null : (user  ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;

  AuthNotifier(this._service) : super(const AuthState(isLoading: true)) {
    _init();
    AuthService.onForcedLogout.listen((_) async {
      await _service.logout();
      state = const AuthState();
    });
  }

  Future<void> _init() async {
    final user = await _service.restoreSession();
    state = AuthState(user: user);
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.login(email, password);
      state = AuthState(user: user);
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
        clearUser: true,
      );
      rethrow;
    }
  }

  Future<void> register(
      String email, String password, String? displayName) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.register(email, password, displayName);
      state = AuthState(user: user);
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
        clearUser: true,
      );
      rethrow;
    }
  }

  Future<void> logout() async {
    await _service.logout();
    state = const AuthState();
  }

  static String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('401') || msg.contains('Invalid email')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('409') || msg.contains('already registered')) {
      return 'Email already registered.';
    }
    if (msg.contains('SocketException') || msg.contains('connection')) {
      return 'Cannot reach the server. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((_) => AuthService());

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authServiceProvider));
});
