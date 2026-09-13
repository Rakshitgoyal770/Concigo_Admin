import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildSection(
              '1. Introduction',
              'Concigo ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard information when you use our hotel administration platform. By using the Service, you consent to the practices described in this policy.',
            ),
            _buildSection(
              '2. Information We Collect',
              'We may collect the following types of information:\n\n• Account Information: Name, phone number, role, and property association provided during registration.\n• Usage Data: Log data, device information, IP addresses, and interaction patterns within the platform.\n• Property Data: Guest check-in/check-out records, service requests, billing information, and operational data entered by authorized users.\n• Communication Data: Messages or support requests submitted through the platform.',
            ),
            _buildSection(
              '3. How We Use Your Information',
              'We use the collected information to:\n\n• Provide, operate, and maintain the Concigo platform.\n• Authenticate users and manage access control.\n• Process and fulfill service requests within the platform.\n• Improve platform features and user experience.\n• Send administrative communications, including security alerts and updates.\n• Comply with legal obligations and enforce our Terms.',
            ),
            _buildSection(
              '4. Data Sharing and Disclosure',
              'We do not sell, trade, or rent your personal information to third parties. We may share data with:\n\n• Service Providers: Trusted third-party vendors who assist in operating the platform (e.g., cloud hosting, OTP services), bound by confidentiality agreements.\n• Legal Requirements: When required by law, regulation, or legal process.\n• Business Transfers: In connection with a merger, acquisition, or sale of assets, with appropriate confidentiality protections.',
            ),
            _buildSection(
              '5. Data Security',
              'We implement industry-standard security measures to protect your data, including encryption in transit (TLS/HTTPS), secure authentication protocols, and access controls. However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.',
            ),
            _buildSection(
              '6. Data Retention',
              'We retain personal data for as long as necessary to provide the Service and fulfill the purposes outlined in this policy, or as required by applicable law. Upon account termination, we will delete or anonymize your data within a reasonable timeframe, unless retention is required by law.',
            ),
            _buildSection(
              '7. Your Rights',
              'Depending on your jurisdiction, you may have the right to:\n\n• Access the personal data we hold about you.\n• Request correction of inaccurate data.\n• Request deletion of your personal data.\n• Object to or restrict certain processing activities.\n• Data portability where technically feasible.\n\nTo exercise these rights, contact us at contact@concigo.in.',
            ),
            _buildSection(
              '8. Cookies and Tracking',
              'The Concigo platform may use cookies and similar tracking technologies to enhance functionality and analyze usage. You can control cookie settings through your browser, though disabling cookies may affect certain platform features.',
            ),
            _buildSection(
              '9. Children\'s Privacy',
              'The Concigo platform is not intended for use by individuals under the age of 18. We do not knowingly collect personal information from minors. If we become aware of such collection, we will promptly delete the information.',
            ),
            _buildSection(
              '10. Changes to This Policy',
              'We may update this Privacy Policy periodically. Changes will be posted on the platform with an updated effective date. Continued use of the Service after changes constitutes acceptance of the revised policy.',
            ),
            _buildSection(
              '11. Contact Us',
              'For privacy-related inquiries or to exercise your data rights, please contact:\n\nConcigo\nEmail: contact@concigo.in\nWebsite: www.concigo.in',
            ),
            const SizedBox(height: 12),
            _buildFooter(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            'Privacy Policy',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Concigo · Effective from 2026',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your privacy matters to us. Learn how we protect your data.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppTheme.onSurfaceMuted,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.outlineVariant, height: 1),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '© 2026 Concigo. All rights reserved.\nwww.concigo.in',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppTheme.onSurfaceMuted,
          height: 1.6,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
