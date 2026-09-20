/// Application-wide constants.
class AppConstants {
  AppConstants._();

  // ── App Info ──
  static const String appName = 'KrushiSarthi';
  static const String appSubtitle = 'AI-Based Crop & Soil Management';
  static const String appVersion = '1.0.0';

  // ── Storage Keys ──
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyDemoMode = 'demo_mode';
  static const String keyThemeMode = 'theme_mode';
  static const String keyActiveFarmId = 'active_farm_id';
  static const String keyAuthToken = 'auth_token';

  // ── Hive Box Names ──
  static const String boxSoilCache = 'soil_cache';
  static const String boxEnvironmentCache = 'environment_cache';
  static const String boxCropHealthCache = 'crop_health_cache';
  static const String boxDiseaseHistory = 'disease_history';
  static const String boxSchemes = 'schemes_cache';
  static const String boxNotifications = 'notifications_cache';
  static const String boxFarms = 'farms_cache';
  static const String boxProfile = 'profile_cache';
  static const String boxBookmarkedSchemes = 'bookmarked_schemes';

  // ── Splash ──
  static const Duration splashDuration = Duration(milliseconds: 2500);

  // ── Refresh ──
  static const Duration cacheExpiry = Duration(minutes: 30);
  static const Duration autoRefreshInterval = Duration(minutes: 5);

  // ── Chart Periods ──
  static const String period24h = '24h';
  static const String period7d = '7d';
  static const String period30d = '30d';

  // ── Scheme Categories ──
  static const List<String> schemeCategories = [
    'All',
    'Financial Assistance',
    'Insurance',
    'Irrigation',
    'Equipment',
    'Fertilizer',
    'Farmer Welfare',
  ];

  // ── Indian States ──
  static const List<String> indianStates = [
    'All States',
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
  ];

  // ── Soil Types ──
  static const List<String> soilTypes = [
    'Alluvial',
    'Black (Regur)',
    'Red',
    'Laterite',
    'Desert (Arid)',
    'Mountain',
    'Clay',
    'Sandy',
    'Loamy',
  ];

  // ── Notification Categories ──
  static const List<String> notificationCategories = [
    'All',
    'Soil Alerts',
    'Environmental Alerts',
    'Crop Health Alerts',
    'Disease Alerts',
    'Scheme Updates',
  ];
}
