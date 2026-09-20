/// API endpoint constants for the FastAPI backend.
/// All endpoints are centralized here — never hardcode URLs in widgets.
class ApiConstants {
  ApiConstants._();

  // Base URL — configurable per environment
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  // ── Auth ──
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';

  // ── Farms ──
  static const String farms = '/api/farms';

  // ── Soil ──
  static const String soilCurrent = '/api/soil/current';
  static const String soilHistory = '/api/soil/history';

  // ── Environment ──
  static const String environmentCurrent = '/api/environment/current';
  static const String environmentHistory = '/api/environment/history';

  // ── Crop Health ──
  static const String cropHealth = '/api/crop/health';
  static const String ndviHistory = '/api/crop/ndvi/history';

  // ── Disease Detection ──
  static const String diseaseDetect = '/api/disease/detect';
  static const String diseaseHistory = '/api/disease/history';

  // ── Government Schemes ──
  static const String schemes = '/api/schemes';
  static String schemeDetail(String id) => '/api/schemes/$id';

  // ── Notifications ──
  static const String notifications = '/api/notifications';

  // ── Profile ──
  static const String profile = '/api/profile';

  // ── Timeouts ──
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration imageUploadTimeout = Duration(seconds: 60);
}
