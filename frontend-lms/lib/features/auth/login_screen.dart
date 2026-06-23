import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _nameCtrl    = TextEditingController();

  bool _isRegister    = false;
  bool _obscure       = true;
  bool _submitting    = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _submitting = true; _errorMsg = null; });
    try {
      final notifier = ref.read(authProvider.notifier);
      if (_isRegister) {
        await notifier.register(
          _emailCtrl.text.trim(),
          _passCtrl.text,
          _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        );
      } else {
        await notifier.login(_emailCtrl.text.trim(), _passCtrl.text);
      }
      // Router's redirect will navigate away automatically.
    } catch (_) {
      final auth = ref.read(authProvider);
      setState(() {
        _submitting = false;
        _errorMsg   = auth.error ?? 'Something went wrong.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: ArrestoColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ArrestoSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo / branding
                const SizedBox(height: ArrestoSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ArrestoColors.amber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: ArrestoColors.ink, size: 28),
                    ),
                    const SizedBox(width: ArrestoSpacing.sm),
                    Text('Arresto LMS', style: ArrestoText.h2()),
                  ],
                ),
                const SizedBox(height: ArrestoSpacing.sm),
                Text(
                  _isRegister
                      ? 'Create your learner account'
                      : 'Sign in to continue',
                  textAlign: TextAlign.center,
                  style: ArrestoText.bodyMd()
                      .copyWith(color: ArrestoColors.textMuted),
                ),

                const SizedBox(height: ArrestoSpacing.xxl),

                // Card
                Container(
                  decoration: BoxDecoration(
                    color: ArrestoColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ArrestoColors.cardBorder),
                    boxShadow: ArrestoColors.sh2,
                  ),
                  padding: const EdgeInsets.all(ArrestoSpacing.xl),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isRegister) ...[
                          _field(
                            controller: _nameCtrl,
                            label: 'Full name',
                            hint: 'Your name (optional)',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: ArrestoSpacing.md),
                        ],
                        _field(
                          controller: _emailCtrl,
                          label: 'Email',
                          hint: 'you@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required.';
                            }
                            if (!v.contains('@')) return 'Enter a valid email.';
                            return null;
                          },
                        ),
                        const SizedBox(height: ArrestoSpacing.md),
                        _field(
                          controller: _passCtrl,
                          label: 'Password',
                          hint: _isRegister
                              ? 'Min 8 characters'
                              : '••••••••',
                          icon: Icons.lock_outline,
                          obscureText: _obscure,
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password is required.';
                            }
                            if (_isRegister && v.length < 8) {
                              return 'Password must be at least 8 characters.';
                            }
                            return null;
                          },
                        ),

                        if (_errorMsg != null) ...[
                          const SizedBox(height: ArrestoSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(ArrestoSpacing.sm),
                            decoration: BoxDecoration(
                              color: ArrestoColors.redSoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: ArrestoColors.red, size: 16),
                                const SizedBox(width: ArrestoSpacing.xs),
                                Expanded(
                                  child: Text(_errorMsg!,
                                      style: ArrestoText.bodySm().copyWith(
                                          color: ArrestoColors.red)),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: ArrestoSpacing.lg),

                        // Submit button
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: ArrestoColors.amber,
                            foregroundColor: ArrestoColors.ink,
                            padding: const EdgeInsets.symmetric(
                                vertical: ArrestoSpacing.md),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: ArrestoColors.ink),
                                )
                              : Text(
                                  _isRegister ? 'Create account' : 'Sign in',
                                  style: ArrestoText.bodyMd()),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: ArrestoSpacing.lg),

                // Toggle register / login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isRegister
                          ? 'Already have an account?'
                          : "Don't have an account?",
                      style: ArrestoText.bodySm()
                          .copyWith(color: ArrestoColors.textMuted),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _isRegister = !_isRegister;
                        _errorMsg   = null;
                      }),
                      child: Text(
                        _isRegister ? 'Sign in' : 'Create account',
                        style: ArrestoText.bodySm().copyWith(
                            color: ArrestoColors.orange,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ArrestoSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: ArrestoText.label()
                .copyWith(color: ArrestoColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          controller:   controller,
          keyboardType: keyboardType,
          obscureText:  obscureText,
          validator:    validator,
          decoration: InputDecoration(
            hintText:       hint,
            hintStyle: TextStyle(color: ArrestoColors.textMuted2),
            prefixIcon: Icon(icon, size: 18, color: ArrestoColors.textMuted),
            suffixIcon: suffixIcon,
            filled:     true,
            fillColor:  ArrestoColors.surfaceSoft,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: ArrestoSpacing.md, vertical: ArrestoSpacing.sm),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ArrestoColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ArrestoColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: ArrestoColors.amber, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: ArrestoColors.red),
            ),
          ),
        ),
      ],
    );
  }
}
