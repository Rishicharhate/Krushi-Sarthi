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

  // ── Advisory Agent ──
  static const String advisoryAsk = '/api/advisory/ask';

  // ── Recommendation ──
  static const String recommendCrop = '/api/recommend/crop';
  static const String recommendFertilizer = '/api/recommend/fertilizer';

  // ── Government Schemes ──
  static const String schemes = '/api/schemes';
  static const String schemeSearch = '/api/schemes/search';
  static String schemeDetail(String id) => '/api/schemes/$id';

  // ── Notifications ──
  static const String notifications = '/api/notifications';
  static const String notificationsRunDaily = '/api/notifications/run-daily';

  // ── Profile ──
  static const String profile = '/api/profile';

  // ── Timeouts ──
  // connectTimeout must comfortably exceed the slowest backend call: SoilGrids
  // (app/connectors/soilgrids.py) alone can take 10-20s+ from ISRIC's servers,
  // observed directly, before the backend's own 20s httpx timeout even fires.
  // 15s was tighter than that and caused spurious "connection timeout" errors
  // on the soil screen. On Flutter Web, Dio's browser (XHR) adapter also
  // appears to bound the whole request by connectTimeout rather than only the
  // initial handshake, so this needs the same headroom on every platform.
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration imageUploadTimeout = Duration(seconds: 60);
}
