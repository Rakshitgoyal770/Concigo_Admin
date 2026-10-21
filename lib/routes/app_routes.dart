import 'package:flutter/material.dart';
import '../presentation/landing_screen/landing_screen.dart';
import '../presentation/login_verification_screen/login_verification_screen.dart';
import '../presentation/role_based_dashboard_screen/role_based_dashboard_screen.dart';
import '../presentation/info_screens/terms_and_conditions_screen.dart';
import '../presentation/info_screens/privacy_policy_screen.dart';
import '../presentation/info_screens/contact_us_screen.dart';
import '../services/supabase_service.dart';

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
    // Route guard: the dashboard is driven by the verified session only.
    // Navigation arguments are not trusted (with none, this used to open
    // Reception for the first active hotel without any login).
    roleBasedDashboardScreen: (context) {
      final session = SupabaseService.instance.currentSession;
      if (session == null) return const LandingScreen();
      final fullName = '${session.empFirstName} ${session.empLastName}'.trim();
      return RoleBasedDashboardScreen(
        role: session.role,
        employeeName: fullName.isEmpty ? 'Staff' : fullName,
        propertyName: session.propertyName,
        propertyId: session.propertyId,
        serviceId: session.serviceDept,
        empId: session.empId,
      );
    },
    termsAndConditionsScreen: (context) => const TermsAndConditionsScreen(),
    privacyPolicyScreen: (context) => const PrivacyPolicyScreen(),
    contactUsScreen: (context) => const ContactUsScreen(),
  };
}
