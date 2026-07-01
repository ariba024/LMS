import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/arresto_card.dart';
import '../../../core/widgets/badge.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/arresto_ai_mascot.dart';
import '../../../data/providers/app_state.dart';
import '../../shared/arresto_ai/arresto_ai_panel.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = 'Technical';
  bool _submitted = false;

  static const _categories = [
    'Technical',
    'Certificates',
    'Assessments',
    'Billing',
    'Other',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(ticketsProvider);
    final tickets = ticketsAsync.valueOrNull ?? [];
    final isWide = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
            ),
            const SizedBox(height: 20),
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _ContactForm()),
                      const SizedBox(width: 20),
                      Expanded(child: _SidePanel()),
                    ],
                  )
                : Column(
                    children: [
                      _ContactForm(),
                      const SizedBox(height: 16),
                      _SidePanel(),
                    ],
                  ),
            const SizedBox(height: 24),
            _MyTickets(tickets: tickets),
          ],
        ),
      );
  }
}

class _ContactForm extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  final _formKey    = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();
  String _category   = 'Technical';
  bool   _sent       = false;
  bool   _loading    = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ref.read(ticketsProvider.notifier).createTicket(
        subject:     _subjectCtrl.text.trim(),
        category:    _category,
        priority:    'Medium',
        description: _descCtrl.text.trim(),
      );
      setState(() { _sent = true; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return ArrestoCard(
        child: Column(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: ArrestoColors.green, size: 48),
            const SizedBox(height: 12),
            Text('Ticket Submitted!', style: ArrestoText.h3()),
            const SizedBox(height: 6),
            Text('We\'ll get back to you within 24 hours.',
                style: ArrestoText.body(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ArrestoButton(
              label: 'Submit Another',
              variant: ArrestoButtonVariant.ghost,
              onPressed: () => setState(() {
                _sent = false;
                _subjectCtrl.clear();
                _descCtrl.clear();
              }),
            ),
          ],
        ),
      );
    }

    return ArrestoCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Admin', style: ArrestoText.h3()),
            const SizedBox(height: 16),
            _field('Subject', controller: _subjectCtrl,
                hintText: 'Brief description of your issue',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 12),
            _dropdown(),
            const SizedBox(height: 12),
            _field('Issue Description', controller: _descCtrl,
                maxLines: 5,
                hintText: 'Please describe your issue in detail...',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
            const SizedBox(height: 16),
            ArrestoButton(
              label: _loading ? 'Submitting...' : 'Submit Ticket',
              fullWidth: true,
              size: ArrestoButtonSize.lg,
              icon: const Icon(Icons.send_rounded),
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, {
    required TextEditingController controller,
    int maxLines = 1,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArrestoText.label()),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines:   maxLines,
          validator:  validator,
          decoration: InputDecoration(hintText: hintText),
        ),
      ],
    );
  }

  Widget _dropdown() {
    const cats = ['Technical', 'Certificates', 'Assessments', 'Billing', 'Other'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Category', style: ArrestoText.label()),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: const InputDecoration(),
          items: cats
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) { if (v != null) setState(() => _category = v); },
        ),
      ],
    );
  }
}

class _SidePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ArrestoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FAQ', style: ArrestoText.h4()),
              const SizedBox(height: 12),
              ...[
                'How do I download my certificate?',
                'Why is my assessment locked?',
                'How do I reset my progress?',
                'Can I access courses offline?',
              ].map((q) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: ArrestoColors.orange),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(q,
                                style: ArrestoText.bodySm(
                                    color: ArrestoColors.blue))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF191200),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: ArrestoColors.amber.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ArrestoAiAvatar(size: 32, circle: true),
                  const SizedBox(width: 8),
                  Text('Try Arresto AI first',
                      style: ArrestoText.bodyBold(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Get instant answers to your learning questions.',
                  style: ArrestoText.small(color: ArrestoColors.textMuted)),
              const SizedBox(height: 12),
              ArrestoButton(
                label: 'Ask AI',
                size: ArrestoButtonSize.sm,
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const ArrestoAIPanel(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MyTickets extends ConsumerWidget {
  final List tickets;
  const _MyTickets({required this.tickets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tickets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Support Requests', style: ArrestoText.h3()),
        const SizedBox(height: 12),
        ...tickets.take(3).map((t) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: ArrestoColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ArrestoColors.cardBorder),
              ),
              child: Row(
                children: [
                  Text(t.id,
                      style: ArrestoText.mono()
                          .copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(t.subject,
                          style: ArrestoText.body(color: ArrestoColors.textPrimary),
                          overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  StatusBadge(status: t.status),
                  const SizedBox(width: 8),
                  Text(t.date, style: ArrestoText.xs()),
                ],
              ),
            )),
      ],
    );
  }
}
