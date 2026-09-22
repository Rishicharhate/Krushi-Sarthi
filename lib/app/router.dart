import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/dashboard/main_shell.dart';
import '../features/soil_monitoring/soil_monitoring_screen.dart';
import '../features/soil_monitoring/soil_history_screen.dart';
import '../features/environmental_monitoring/environment_screen.dart';
import '../features/environmental_monitoring/environment_history_screen.dart';
import '../features/crop_health/crop_health_screen.dart';
import '../features/crop_health/ndvi_history_screen.dart';
import '../features/crop_health/crop_map_screen.dart';
import '../features/disease_detection/disease_detection_screen.dart';
import '../features/disease_detection/disease_result_screen.dart';
import '../features/disease_detection/disease_history_screen.dart';
import '../features/advisory/advisory_chat_screen.dart';
import '../features/market/market_prices_screen.dart';
import '../features/recommendation/recommendation_hub_screen.dart';
import '../features/recommendation/crop_recommendation_screen.dart';
import '../features/recommendation/fertilizer_recommendation_screen.dart';
import '../features/government_schemes/schemes_screen.dart';
import '../features/government_schemes/scheme_detail_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/farm/farm_management_screen.dart';
import '../features/farm/add_edit_farm_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/about_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration for the entire app.
final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    // ── Splash ──
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),

    // ── Onboarding ──
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),

    // ── Main Shell with Bottom Navigation ──
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/monitoring',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SoilMonitoringScreen(),
          ),
          routes: [
            GoRoute(
              path: 'history',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const SoilHistoryScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/crop-health',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: CropHealthScreen(),
          ),
          routes: [
            GoRoute(
              path: 'history',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const NdviHistoryScreen(),
            ),
            GoRoute(
              path: 'map',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const CropMapScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/disease',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DiseaseDetectionScreen(),
          ),
          routes: [
            GoRoute(
              path: 'result',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const DiseaseResultScreen(),
            ),
            GoRoute(
              path: 'history',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const DiseaseHistoryScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/schemes',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SchemesScreen(),
          ),
          routes: [
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return SchemeDetailScreen(schemeId: id);
              },
            ),
          ],
        ),
      ],
    ),

    // ── Standalone Screens (outside bottom nav) ──
    GoRoute(
      path: '/environment',
      builder: (context, state) => const EnvironmentScreen(),
      routes: [
        GoRoute(
          path: 'history',
          builder: (context, state) => const EnvironmentHistoryScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/market',
      builder: (context, state) => const MarketPricesScreen(),
    ),
    GoRoute(
      path: '/advisory',
      builder: (context, state) => const AdvisoryChatScreen(),
    ),
    GoRoute(
      path: '/recommend',
      builder: (context, state) => const RecommendationHubScreen(),
      routes: [
        GoRoute(
          path: 'crop',
          builder: (context, state) => const CropRecommendationScreen(),
        ),
        GoRoute(
          path: 'fertilizer',
          builder: (context, state) => const FertilizerRecommendationScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      path: '/farms',
      builder: (context, state) => const FarmManagementScreen(),
    ),
    GoRoute(
      path: '/farms/add',
      builder: (context, state) => const AddEditFarmScreen(),
    ),
    GoRoute(
      path: '/farms/edit/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AddEditFarmScreen(farmId: id);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
  ],
);
