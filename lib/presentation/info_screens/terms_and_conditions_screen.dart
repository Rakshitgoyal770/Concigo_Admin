import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF3730A3),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Terms & Conditions',
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
              '1. Acceptance of Terms',
              'By accessing or using the Concigo platform ("Service"), you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the Service. These terms apply to all users, including administrators, managers, and staff members.',
            ),
            _buildSection(
              '2. Use of the Service',
              'The Concigo platform is intended solely for authorized personnel of registered properties. You agree to:\n\n• Use the Service only for lawful purposes and in accordance with these Terms.\n• Not share your login credentials with unauthorized individuals.\n• Maintain the confidentiality of your account information.\n• Notify Concigo immediately of any unauthorized use of your account.',
            ),
            _buildSection(
              '3. User Accounts',
              'Access to the Service requires a valid account. You are responsible for all activities that occur under your account. Concigo reserves the right to suspend or terminate accounts that violate these Terms or engage in fraudulent, abusive, or otherwise unacceptable behavior.',
            ),
            _buildSection(
              '4. Data and Privacy',
              'By using the Service, you acknowledge that Concigo may collect and process data as described in our Privacy Policy. You agree to handle all guest and property data in compliance with applicable data protection laws and regulations.',
            ),
            _buildSection(
              '5. Intellectual Property',
              'All content, features, and functionality of the Concigo platform — including but not limited to software, text, graphics, logos, and icons — are the exclusive property of Concigo and are protected by applicable intellectual property laws. Unauthorized reproduction or distribution is strictly prohibited.',
            ),
            _buildSection(
              '6. Limitation of Liability',
              'To the fullest extent permitted by law, Concigo shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of or inability to use the Service. Concigo\'s total liability shall not exceed the fees paid by you in the twelve (12) months preceding the claim.',
            ),
            _buildSection(
              '7. Service Availability',
              'Concigo strives to maintain high availability of the Service but does not guarantee uninterrupted access. Scheduled maintenance, updates, or unforeseen technical issues may temporarily affect availability. Concigo will endeavor to provide advance notice of planned downtime.',
            ),
            _buildSection(
              '8. Modifications to Terms',
              'Concigo reserves the right to modify these Terms at any time. Changes will be communicated through the platform or via email. Continued use of the Service after modifications constitutes acceptance of the updated Terms.',
            ),
            _buildSection(
              '9. Governing Law',
              'These Terms shall be governed by and construed in accordance with the laws of India. Any disputes arising under these Terms shall be subject to the exclusive jurisdiction of the courts located in India.',
            ),
            _buildSection(
              '10. Contact',
              'For questions regarding these Terms and Conditions, please contact us at:\n\nEmail: contact@concigo.in\nWebsite: www.concigo.in',
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
          colors: [Color(0xFF3730A3), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gavel_rounded, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            'Terms & Conditions',
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
            'Please read these terms carefully before using the platform.',
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
