import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/widgets/arresto_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameCtrl  = TextEditingController(text: 'Ariba');
  final _emailCtrl = TextEditingController(text: 'ariba@arresto.in');
  String _role = 'admin';
  bool _loading = false;

  Future<void> _login() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).login(name, email, _role);
    if (mounted) context.go(_role == 'admin' ? '/admin' : '/learner');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Logo
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: AColors.ink, borderRadius: BorderRadius.circular(14)),
              child: Center(child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AColors.amber, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('A', style: TextStyle(
                    color: AColors.ink, fontWeight: FontWeight.w800, fontSize: 22))),
              )),
            ),
            const SizedBox(height: 20),
            const Text('Arresto LMS', style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, color: AColors.ink, letterSpacing: -0.3)),
            const SizedBox(height: 6),
            const Text('YOUR FALL ARREST EXPERT', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: AColors.textMuted, letterSpacing: 1.5)),
            const SizedBox(height: 40),
            // Login card
            Container(
              width: 420,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AColors.cardBorder),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Sign in', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AColors.ink)),
                const SizedBox(height: 4),
                const Text('Continue to Arresto LMS', style: TextStyle(fontSize: 13, color: AColors.textMuted)),
                const SizedBox(height: 24),

                const Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AColors.ink)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: 'Your name'),
                ),
                const SizedBox(height: 16),

                const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AColors.ink)),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(hintText: 'you@arresto.in'),
                ),
                const SizedBox(height: 16),

                const Text('Sign in as', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AColors.ink)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _RoleCard(
                    label: 'Admin',
                    subtitle: 'Manage courses & learners',
                    icon: Icons.admin_panel_settings_rounded,
                    selected: _role == 'admin',
                    onTap: () => setState(() => _role = 'admin'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _RoleCard(
                    label: 'Learner',
                    subtitle: 'Browse & take courses',
                    icon: Icons.school_rounded,
                    selected: _role == 'learner',
                    onTap: () => setState(() => _role = 'learner'),
                  )),
                ]),
                const SizedBox(height: 24),
                AButton(
                  label: 'Sign in',
                  onPressed: _login,
                  loading: _loading,
                  fullWidth: true,
                  size: AButtonSize.lg,
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.label, required this.subtitle, required this.icon,
      required this.selected, required this.onTap});
  final String label, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AColors.amberSoft : AColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? AColors.amber : AColors.cardBorder, width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, size: 26, color: selected ? AColors.orange : AColors.textMuted),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: selected ? AColors.ink : AColors.textSecond)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AColors.textMuted),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
