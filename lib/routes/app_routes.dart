import 'package:flutter/material.dart';
import '../presentation/landing_screen/landing_screen.dart';
import '../presentation/login_verification_screen/login_verification_screen.dart';
import '../presentation/role_based_dashboard_screen/role_based_dashboard_screen.dart';
import '../presentation/info_screens/terms_and_conditions_screen.dart';
import '../presentation/info_screens/privacy_policy_screen.dart';
import '../presentation/info_screens/contact_us_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String landingScreen = '/landing-screen';
  static const String loginVerificationScreen = '/login-verification-screen';
  static const String roleBasedDashboardScreen = '/role-based-dashboard-screen';
  static const String termsAndConditionsScreen = '/terms-and-conditions';
  static const String privacyPolicyScreen = '/privacy-policy';
  static const String contactUsScreen = '/contact-us';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const LandingScreen(),
    landingScreen: (context) => const LandingScreen(),
    loginVerificationScreen: (context) => const LoginVerificationScreen(),
    roleBasedDashboardScreen: (context) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      return RoleBasedDashboardScreen(
        role: args?['role'] as String? ?? 'RECEPTION_DESK',
        employeeName: args?['employeeName'] as String? ?? 'Staff',
        propertyName: args?['propertyName'] as String? ?? 'Zappy Hotel',
        propertyId: args?['propertyId'] as String? ?? '',
        serviceId: args?['serviceId'] as String?,
        empId: args?['empId'] as String?,
      );
    },
    termsAndConditionsScreen: (context) => const TermsAndConditionsScreen(),
    privacyPolicyScreen: (context) => const PrivacyPolicyScreen(),
    contactUsScreen: (context) => const ContactUsScreen(),
  };
}
