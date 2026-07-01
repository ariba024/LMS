import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/arresto_brand_logo.dart';
import '../../core/widgets/arresto_circuit_background.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _nameCtrl   = TextEditingController();
  bool _isRegister  = false;
  bool _obscure     = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authProvider.notifier);
    if (_isRegister) {
      await notifier.register(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        displayName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
    } else {
      await notifier.login(_emailCtrl.text.trim(), _passCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.isAuthenticated) {
        final user = next.user!;
        context.go(user.isAdmin ? '/admin' : '/learner');
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ArrestoCircuitBackground(
        child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                const Center(child: ArrestoBrandLogo()),
                const SizedBox(height: 32),

                // Card
                Container(
                  decoration: BoxDecoration(
                    color: ArrestoColors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: ArrestoColors.amber.withValues(alpha: 0.18)),
                    boxShadow: ArrestoColors.sh4,
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isRegister ? 'Create account' : 'Sign in',
                          style: ArrestoText.h2(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRegister
                              ? 'Start your safety training journey'
                              : 'Welcome back to Arresto LMS',
                          style: ArrestoText.body(),
                        ),
                        const SizedBox(height: 24),

                        if (_isRegister) ...[
                          _label('Display name (optional)'),
                          const SizedBox(height: 6),
                          _field(
                            controller: _nameCtrl,
                            hint: 'Your name',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 16),
                        ],

                        _label('Email address'),
                        const SizedBox(height: 6),
                        _field(
                          controller: _emailCtrl,
                          hint: 'you@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        _label('Password'),
                        const SizedBox(height: 6),
                        _field(
                          controller: _passCtrl,
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              size: 20,
                              color: ArrestoColors.textMuted,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v.length < 6) return 'At least 6 characters';
                            return null;
                          },
                        ),

                        if (auth.error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: ArrestoColors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ArrestoColors.red.withOpacity(0.3)),
                            ),
                            child: Text(auth.error!, style: ArrestoText.body(color: ArrestoColors.red)),
                          ),
                        ],

                        const SizedBox(height: 24),

                        SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: auth.isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ArrestoColors.amber,
                              foregroundColor: ArrestoColors.ink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: ArrestoColors.ink,
                                    ),
                                  )
                                : Text(
                                    _isRegister ? 'Create account' : 'Sign in',
                                    style: ArrestoText.bodyBold(color: ArrestoColors.ink),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Divider(color: ArrestoColors.line),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isRegister ? 'Already have an account? ' : "Don't have an account? ",
                              style: ArrestoText.body(),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _isRegister = !_isRegister;
                              }),
                              child: Text(
                                _isRegister ? 'Sign in' : 'Register',
                                style: ArrestoText.bodyMd(color: ArrestoColors.amber),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: ArrestoText.label(color: ArrestoColors.textSecondary));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: ArrestoText.body(color: ArrestoColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: ArrestoText.body(),
        prefixIcon: Icon(icon, size: 18, color: ArrestoColors.textMuted),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: ArrestoColors.bg2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ArrestoColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ArrestoColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ArrestoColors.amber, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ArrestoColors.red),
        ),
      ),
    );
  }
}
