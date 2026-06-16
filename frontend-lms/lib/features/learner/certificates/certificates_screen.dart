import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/button.dart';
import '../../../core/widgets/section_header.dart';

class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key});

  static const _certs = [
    (
      'Harness Inspection & Fit',
      'EQP-042',
      'James Harrington',
      '28 May 2026',
      'CERT-2026-0428',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              icon: Icons.workspace_premium_rounded,
              title: 'My Certificates',
              subtitle: '${_certs.length} certificate earned',
            ),
            const SizedBox(height: 20),
            ..._certs.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _CertificateCard(cert: c),
                )),
          ],
        ),
      );
  }
}

class _CertificateCard extends StatelessWidget {
  final (String, String, String, String, String) cert;
  const _CertificateCard({required this.cert});

  @override
  Widget build(BuildContext context) {
    final (title, code, name, date, certId) = cert;

    return Container(
      decoration: BoxDecoration(
        color: ArrestoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ArrestoColors.amber, width: 2),
        boxShadow: ArrestoColors.sh2,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                // Logo
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ArrestoColors.amber,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('A',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: ArrestoColors.ink)),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ARRESTO LMS',
                        style: ArrestoText.eyebrow(color: ArrestoColors.ink)
                            .copyWith(letterSpacing: 1.5)),
                    Text('Accredited Training Provider',
                        style: ArrestoText.xs()),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ArrestoColors.blueSoft,
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: ArrestoColors.blue),
                  ),
                  child: Text('ISO 45001',
                      style: ArrestoText.xs(
                              color: ArrestoColors.blue)
                          .copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: ArrestoColors.line),
            const SizedBox(height: 12),

            // Certificate body
            Text(
              'CERTIFICATE OF COMPLETION',
              style: ArrestoText.eyebrow(color: ArrestoColors.orange)
                  .copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Text(title, style: ArrestoText.h2()),
            const SizedBox(height: 8),
            Text('Awarded to', style: ArrestoText.small()),
            Text(name, style: ArrestoText.h3()),
            const SizedBox(height: 12),
            Row(
              children: [
                _info('Issue Date', date),
                const SizedBox(width: 24),
                _info('Certificate ID', certId),
                const SizedBox(width: 24),
                _info('Course Code', code),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: ArrestoColors.line),
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                ArrestoButton(
                  label: 'Download PDF',
                  icon: const Icon(Icons.download_rounded),
                  onPressed: () {},
                ),
                const SizedBox(width: 10),
                ArrestoButton(
                  label: 'Share',
                  variant: ArrestoButtonVariant.ghost,
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: ArrestoText.xs()),
        Text(value,
            style: ArrestoText.small(color: ArrestoColors.ink)
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
