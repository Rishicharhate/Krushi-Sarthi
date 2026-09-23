import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../core/constants/app_constants.dart';
import '../core/mock/mock_data.dart';
import '../core/network/api_client.dart';
import '../core/storage/local_storage.dart';
import '../shared/models/soil_data.dart';
import '../shared/models/environment_data.dart';
import '../shared/models/crop_health.dart';
import '../shared/models/disease_result.dart';
import '../shared/models/government_scheme.dart';
import '../shared/models/farm.dart';
import '../shared/models/farmer_profile.dart';
import '../shared/models/notification_item.dart';
import '../shared/models/recommendation.dart';
import '../shared/models/advisory.dart';
import '../shared/models/market_price.dart';

// ══════════════════════════════════════════════════════════════
// CORE PROVIDERS
// ══════════════════════════════════════════════════════════════

/// SharedPreferences instance — initialized at app startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden with actual instance');
});

/// Local storage wrapper.
final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage(ref.watch(sharedPreferencesProvider));
});

/// Demo mode toggle — persisted.
final demoModeProvider = StateNotifierProvider<DemoModeNotifier, bool>((ref) {
  final storage = ref.watch(localStorageProvider);
  return DemoModeNotifier(storage);
});

class DemoModeNotifier extends StateNotifier<bool> {
  final LocalStorage _storage;

  DemoModeNotifier(this._storage)
      : super(_storage.getBool(AppConstants.keyDemoMode, defaultValue: true));

  void toggle() {
    state = !state;
    _storage.setBool(AppConstants.keyDemoMode, state);
  }

  void setDemoMode(bool value) {
    state = value;
    _storage.setBool(AppConstants.keyDemoMode, value);
  }
}

/// Theme mode — persisted.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final LocalStorage _storage;

  ThemeModeNotifier(this._storage) : super(_loadThemeMode(_storage));

  static ThemeMode _loadThemeMode(LocalStorage storage) {
    final value = storage.getString(AppConstants.keyThemeMode);
    return switch (value) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    _storage.setString(AppConstants.keyThemeMode, mode.name);
  }

  void toggleDarkMode() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _storage.setString(AppConstants.keyThemeMode, state.name);
  }
}

/// Onboarding completion.
final onboardingCompleteProvider = StateProvider<bool>((ref) {
  final storage = ref.watch(localStorageProvider);
  return storage.getBool(AppConstants.keyOnboardingComplete);
});

/// Connectivity stream.
final connectivityProvider = StreamProvider<bool>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    return results.any((r) => r != ConnectivityResult.none);
  });
});

// ══════════════════════════════════════════════════════════════
// BACKEND AUTH (device-bound — the app has no login screen; see
// backend/app/db/models.py for why. Only used when demo mode is off.)
// ══════════════════════════════════════════════════════════════

const _deviceIdKey = 'device_id';

/// A stable per-install identifier, generated once and cached. Not a real
/// UUID library to avoid an extra dependency — just needs to be unique per
/// install, not cryptographically strong.
final deviceIdProvider = Provider<String>((ref) {
  final storage = ref.watch(localStorageProvider);
  final existing = storage.getString(_deviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final rand = Random.secure();
  final id = List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
  storage.setString(_deviceIdKey, id);
  return id;
});

/// Registers/logs the device in with the backend and caches the bearer
/// token. No-op in demo mode. See ApiConstants.register.
final authTokenProvider = FutureProvider<String?>((ref) async {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return null;

  final storage = ref.watch(localStorageProvider);
  final cached = storage.getString(AppConstants.keyAuthToken);
  if (cached != null && cached.isNotEmpty) return cached;

  final deviceId = ref.watch(deviceIdProvider);
  final bootstrapDio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: ApiConstants.connectTimeout,
  ));
  final response = await bootstrapDio.post(
    ApiConstants.register,
    data: {'device_id': deviceId},
  );
  final token = response.data['token'] as String;
  await storage.setString(AppConstants.keyAuthToken, token);
  return token;
});

/// API client carrying the current auth token. Awaited (not watched
/// synchronously) by every real-mode data provider below, so a request never
/// goes out before the device is registered.
final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) return ApiClient();
  final token = await ref.watch(authTokenProvider.future);
  return ApiClient(authToken: token);
});

/// Manually selected farm id, persisted. Null = fall back to the backend's
/// / MockData's own "active" farm.
final selectedFarmIdProvider = StateNotifierProvider<_SelectedFarmIdNotifier, String?>((ref) {
  final storage = ref.watch(localStorageProvider);
  return _SelectedFarmIdNotifier(storage);
});

class _SelectedFarmIdNotifier extends StateNotifier<String?> {
  final LocalStorage _storage;

  _SelectedFarmIdNotifier(this._storage)
      : super(_storage.getString(AppConstants.keyActiveFarmId));

  void select(String farmId) {
    state = farmId;
    _storage.setString(AppConstants.keyActiveFarmId, farmId);
  }
}

// ══════════════════════════════════════════════════════════════
// FEATURE PROVIDERS
// Demo mode (default, offline) reads MockData. Real mode calls the FastAPI
// backend in backend/ — see docs/IMPLEMENTATION_PLAN.md for the data flow.
// ══════════════════════════════════════════════════════════════

/// Farmer profile.
final farmerProfileProvider = FutureProvider<FarmerProfile>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return MockData.farmerProfile;
});

/// Farms list. Demo mode keeps a mutable in-memory copy of MockData so
/// Add/Edit/Delete work fully offline; real mode calls the backend.
final farmsProvider = FutureProvider<List<Farm>>((ref) async {
  final demoMode = ref.watch(demoModeProvider);
  if (demoMode) {
    await Future.delayed(const Duration(milliseconds: 300));
    return ref.watch(demoFarmsProvider);
  }
  final api = await ref.watch(apiClientProvider.future);
  final response = await api.get<List<dynamic>>(ApiConstants.farms);
  return (response.data ?? [])
      .map((e) => Farm.fromJson(e as Map<String, dynamic>))
      .toList();
});

final demoFarmsProvider = StateNotifierProvider<_DemoFarmsNotifier, List<Farm>>((ref) {
  return _DemoFarmsNotifier();
});

class _DemoFarmsNotifier extends StateNotifier<List<Farm>> {
  _DemoFarmsNotifier() : super(List.of(MockData.farms));

  void add(Farm farm) => state = [...state, farm];
  void update(Farm farm) => state = [for (final f in state) if (f.id == farm.id) farm else f];
  void remove(String id) => state = state.where((f) => f.id != id).toList();
}

/// Create/update/delete a farm, routed to demo storage or the backend.
final farmsRepositoryProvider = Provider<FarmsRepository>((ref) => FarmsRepository(ref));

class FarmsRepository {
  final Ref _ref;
  FarmsRepository(this._ref);

  Future<void> createFarm(Farm farm) async {
    if (_ref.read(demoModeProvider)) {
      final id = 'farm_${DateTime.now().microsecondsSinceEpoch}';
      _ref.read(demoFarmsProvider.notifier).add(farm.copyWith(id: id));
      return;
    }
    final api = await _ref.read(apiClientProvider.future);
    await api.post(ApiConstants.farms, data: farm.toJson()..remove('id'));
    _ref.invalidate(farmsProvider);
  }

  Future<void> updateFarm(Farm farm) async {
    if (_ref.read(demoModeProvider)) {
      _ref.read(demoFarmsProvider.notifier).update(farm);
      return;
    }
    final api = await _ref.read(apiClientProvider.future);
    await api.put('${ApiConstants.farms}/${farm.id}', data: farm.toJson());
    _ref.invalidate(farmsProvider);
  }

  Future<void> deleteFarm(String farmId) async {
    if (_ref.read(demoModeProvider)) {
      _ref.read(demoFarmsProvider.notifier).remove(farmId);
      return;
    }
    final api = await _ref.read(apiClientProvider.future);
    await api.delete('${ApiConstants.farms}/$farmId');
    _ref.invalidate(farmsProvider);
  }
}

/// Active farm: an explicit user selection if there is one, else whichever
/// farm the backend/mock data marks `is_active`, else the first farm. Null
/// while farms are loading or if there are none yet.
final activeFarmProvider = Provider<Farm?>((ref) {
  final farms = ref.watch(farmsProvider).asData?.value;
  if (farms == null || farms.isEmpty) return null;

  final selectedId = ref.watch(selectedFarmIdProvider);
  if (selectedId != null) {
    for (final farm in farms) {
      if (farm.id == selectedId) return farm;
    }
  }
  for (final farm in farms) {
    if (farm.isActive) return farm;
  }
  return farms.first;
});

/// Current soil data — SoilGrids (topsoil baseline) + Open-Meteo (moisture)
/// in real mode; see backend/app/api/soil.py.
final soilDataProvider = FutureProvider<SoilData>((ref) async {
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 600));
    return MockData.soilData;
  }
  final farm = ref.watch(activeFarmProvider);
  if (farm == null || !farm.hasCoordinates) {
    throw StateError(
      'Add a location to your farm to see real soil data (Farms → Edit → Latitude/Longitude).',
    );
  }
  final api = await ref.watch(apiClientProvider.future);
  final response = await api.get<Map<String, dynamic>>(
    ApiConstants.soilCurrent,
    queryParameters: {'farm_id': farm.id},
  );
  return SoilData.fromJson(response.data!);
});

/// Soil history — parameter-dependent.
final selectedSoilParamProvider = StateProvider<String>((ref) => 'Moisture');
final selectedSoilPeriodProvider = StateProvider<String>((ref) => AppConstants.period7d);

final soilHistoryProvider = FutureProvider<List<SoilHistoryPoint>>((ref) async {
  final param = ref.watch(selectedSoilParamProvider);
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 400));
    return switch (param) {
      'pH' => MockData.soilPhHistory(),
      'Temperature' => MockData.soilTemperatureHistory(),
      _ => MockData.soilMoistureHistory(),
    };
  }
  final farm = ref.watch(activeFarmProvider);
  if (farm == null || !farm.hasCoordinates) {
    throw StateError('Add a location to your farm to see real soil history.');
  }
  // The backend intentionally has no real daily series for 'pH' — it's a
  // static soil-survey baseline (SoilGrids), not something that changes day
  // to day, and it 400s on purpose rather than fabricating a trend. Fail
  // here with a message a farmer can actually read, instead of surfacing
  // the raw DioException from that 400.
  if (param == 'pH') {
    throw StateError(
      "pH doesn't have a daily history — it's a soil survey baseline, not "
      'a value that changes day to day. See the Soil screen for the current '
      'reading, or get a free Soil Health Card test at your nearest Krishi '
      'Vigyan Kendra for an updated lab value.',
    );
  }
  final api = await ref.watch(apiClientProvider.future);
  final response = await api.get<List<dynamic>>(
    ApiConstants.soilHistory,
    queryParameters: {'farm_id': farm.id, 'param': param, 'days': 7},
  );
  return (response.data ?? [])
      .map((e) => SoilHistoryPoint.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Soil insights — demo mode uses canned copy; real mode derives short,
/// honest observations from the actual fetched SoilData.
final soilInsightsProvider = FutureProvider<List<SoilInsight>>((ref) async {
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockData.soilInsights;
  }
  final soil = await ref.watch(soilDataProvider.future);
  return _deriveSoilInsights(soil);
});

List<SoilInsight> _deriveSoilInsights(SoilData soil) {
  return [
    SoilInsight(
      message: soil.moistureStatus == 'Low'
          ? 'Soil moisture is low (${soil.moisture.toStringAsFixed(0)}%). Consider irrigating soon.'
          : 'Soil moisture is currently within the recommended range (${soil.moisture.toStringAsFixed(0)}%).',
      type: soil.moistureStatus == 'Low' ? 'warning' : 'success',
    ),
    SoilInsight(
      message: soil.phStatus == 'Normal'
          ? 'Soil pH (${soil.ph.toStringAsFixed(1)}) is suitable for most crops.'
          : 'Soil pH (${soil.ph.toStringAsFixed(1)}) is ${soil.phStatus?.toLowerCase() ?? "out of range"} — this can limit nutrient uptake.',
      type: soil.phStatus == 'Normal' ? 'success' : 'warning',
    ),
    const SoilInsight(
      message:
          'Nitrogen, phosphorus and potassium shown are estimated from regional soil survey '
          'data, not a lab test. For exact values, get a free Soil Health Card test at your '
          'nearest Krishi Vigyan Kendra.',
      type: 'info',
    ),
  ];
}

/// Current environment data — Open-Meteo in real mode; see
/// backend/app/api/environment.py.
final environmentDataProvider = FutureProvider<EnvironmentData>((ref) async {
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.environmentData;
  }
  final farm = ref.watch(activeFarmProvider);
  if (farm == null || !farm.hasCoordinates) {
    throw StateError(
      'Add a location to your farm to see real weather data (Farms → Edit → Latitude/Longitude).',
    );
  }
  final api = await ref.watch(apiClientProvider.future);
  final response = await api.get<Map<String, dynamic>>(
    ApiConstants.environmentCurrent,
    queryParameters: {'farm_id': farm.id},
  );
  return EnvironmentData.fromJson(response.data!);
});

/// Environment history.
final selectedEnvParamProvider = StateProvider<String>((ref) => 'Temperature');
final selectedEnvPeriodProvider = StateProvider<String>((ref) => AppConstants.period7d);

final environmentHistoryProvider = FutureProvider<List<EnvironmentHistoryPoint>>((ref) async {
  final param = ref.watch(selectedEnvParamProvider);
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 400));
    return switch (param) {
      'Humidity' => MockData.humidityHistory(),
      _ => MockData.temperatureHistory(),
    };
  }
  final farm = ref.watch(activeFarmProvider);
  if (farm == null || !farm.hasCoordinates) {
    throw StateError('Add a location to your farm to see real weather history.');
  }
  final api = await ref.watch(apiClientProvider.future);
  final response = await api.get<List<dynamic>>(
    ApiConstants.environmentHistory,
    queryParameters: {'farm_id': farm.id, 'param': param, 'days': 7},
  );
  return (response.data ?? [])
      .map((e) => EnvironmentHistoryPoint.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Environment alerts. No backend endpoint yet — that's the LangGraph agent's
/// job (docs/IMPLEMENTATION_PLAN.md §3), not a plain GET. Demo mode shows
/// sample alerts; real mode shows none rather than fabricating any.
final environmentAlertsProvider = FutureProvider<List<EnvironmentAlert>>((ref) async {
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockData.environmentAlerts;
  }
  return const [];
});

/// Satellite reads are the slowest call in the app: on a cold cache the
/// backend fetches windowed Sentinel-2 COGs for several candidate scenes
/// (~10s measured; instant once cached for the revisit cycle).
///
/// Both timeouts are set deliberately. On Flutter Web, Dio's browser (XHR)
/// adapter bounds the WHOLE request by connectTimeout rather than just the
/// handshake, so a receiveTimeout alone is silently ignored there and the
/// request dies at the global 30s connectTimeout.
final _satelliteTimeouts = Options(
  connectTimeout: const Duration(seconds: 90),
  receiveTimeout: const Duration(seconds: 90),
);

/// Crop health / NDVI — real mode reads cloud-masked Sentinel-2 imagery via
/// the backend (no account needed; see backend/app/connectors/sentinel.py).
/// Satellite reads are slow, hence the longer timeout: the backend fetches
/// windowed COGs over HTTP and the result is cached for a revisit cycle.
final cropHealthProvider = FutureProvider<CropHealth>((ref) async {
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.cropHealth;
  }
  final farm = ref.watch(activeFarmProvider);
  if (farm == null || !farm.hasCoordinates) {
    throw StateError(
      'Add a location to your farm to see real satellite crop health (Farms → Edit → Latitude/Longitude).',
    );
  }
  final api = await ref.watch(apiClientProvider.future);
  try {
    final response = await api.get<Map<String, dynamic>>(
      ApiConstants.cropHealth,
      queryParameters: {'farm_id': farm.id},
      options: _satelliteTimeouts,
    );
    return CropHealth.fromJson(response.data!);
  } on DioException catch (e) {
    throw _satelliteError(e);
  }
});

/// Neither of these is a bug, so show the backend's plain explanation rather
/// than a raw Dio error: 404 means Sentinel-2 had no cloud-free view of the
/// field; 503 means imagery is still being fetched in the background (the
/// first fetch for a field can take a minute or two).
Object _satelliteError(DioException e) {
  final code = e.response?.statusCode;
  if (code == 404 || code == 503) {
    final data = e.response?.data;
    return StateError(
      data is Map && data['detail'] != null
          ? data['detail'].toString()
          : code == 503
              ? 'Fetching satellite imagery for this field. Try again shortly.'
              : 'No cloud-free satellite view of this field recently.',
    );
  }
  return e;
}

/// NDVI history — one point per cloud-free satellite pass.
final ndviHistoryProvider = FutureProvider<List<NdviHistoryPoint>>((ref) async {
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 400));
    return MockData.ndviHistory;
  }
  final farm = ref.watch(activeFarmProvider);
  if (farm == null || !farm.hasCoordinates) {
    throw StateError('Add a location to your farm to see real NDVI history.');
  }
  final api = await ref.watch(apiClientProvider.future);
  try {
    final response = await api.get<List<dynamic>>(
      ApiConstants.ndviHistory,
      queryParameters: {'farm_id': farm.id},
      options: _satelliteTimeouts,
    );
    return (response.data ?? [])
        .map((e) => NdviHistoryPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    throw _satelliteError(e);
  }
});

/// Mandi price search term — empty means "use the active farm's crop".
final marketCommodityProvider = StateProvider<String>((ref) => '');

/// Mandi (APMC) prices from Agmarknet — real in both modes' absence of mock
/// data; demo mode returns a small canned sample.
final marketPricesProvider = FutureProvider<List<MarketPrice>>((ref) async {
  final commodity = ref.watch(marketCommodityProvider).trim();

  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 400));
    return MockData.marketPrices;
  }
  final api = await ref.watch(apiClientProvider.future);
  final farm = ref.watch(activeFarmProvider);
  final response = await api.get<List<dynamic>>(
    ApiConstants.marketPrices,
    queryParameters: {
      if (commodity.isNotEmpty) 'commodity': commodity,
      if (commodity.isEmpty && farm != null) 'farm_id': farm.id,
      'limit': 20,
    },
    options: Options(receiveTimeout: const Duration(seconds: 60)),
  );
  return (response.data ?? [])
      .map((e) => MarketPrice.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Disease detection state. Real mode posts to the confidence-gated cascade
/// in backend/app/ml/disease/ (see docs/IMPLEMENTATION_PLAN.md §1.1); the
/// backend may itself decline with a low-confidence "Uncertain — possible
/// X" result rather than erroring — that is a normal success response, not
/// a failure.
final diseaseDetectionProvider =
    StateNotifierProvider<DiseaseDetectionNotifier, DiseaseDetectionState>((ref) {
  return DiseaseDetectionNotifier(ref);
});

class DiseaseDetectionNotifier extends StateNotifier<DiseaseDetectionState> {
  final Ref _ref;
  DiseaseDetectionNotifier(this._ref) : super(const DiseaseDetectionState());

  void selectImage(String path) {
    state = DiseaseDetectionState(
      status: DiseaseDetectionStatus.imageSelected,
      imagePath: path,
    );
  }

  Future<void> analyzeImage() async {
    final imagePath = state.imagePath;
    if (imagePath == null) return;

    state = state.copyWith(status: DiseaseDetectionStatus.uploading, uploadProgress: 0.0);

    if (_ref.read(demoModeProvider)) {
      for (var i = 0; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        state = state.copyWith(uploadProgress: i / 10);
      }
      state = state.copyWith(status: DiseaseDetectionStatus.analyzing);
      await Future.delayed(const Duration(seconds: 2));
      state = state.copyWith(status: DiseaseDetectionStatus.success, result: MockData.diseaseResult);
      return;
    }

    try {
      final api = await _ref.read(apiClientProvider.future);
      final response = await api.uploadFile<Map<String, dynamic>>(
        ApiConstants.diseaseDetect,
        filePath: imagePath,
        onSendProgress: (sent, total) {
          if (total > 0) {
            state = state.copyWith(uploadProgress: sent / total);
          }
        },
      );
      state = state.copyWith(status: DiseaseDetectionStatus.analyzing);
      state = state.copyWith(
        status: DiseaseDetectionStatus.success,
        result: DiseaseResult.fromJson(response.data!),
      );
      _ref.invalidate(diseaseHistoryProvider);
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['detail'] != null
          ? data['detail'].toString()
          : 'Analysis failed. Please try again.';
      state = state.copyWith(status: DiseaseDetectionStatus.error, errorMessage: message);
    }
  }

  void reset() {
    state = const DiseaseDetectionState();
  }
}

/// Disease history.
final diseaseHistoryProvider = FutureProvider<List<DiseaseResult>>((ref) async {
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockData.diseaseHistory;
  }
  final api = await ref.watch(apiClientProvider.future);
  final response = await api.get<List<dynamic>>(ApiConstants.diseaseHistory);
  return (response.data ?? [])
      .map((e) => DiseaseResult.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Crop & fertilizer recommendation (Phase 3) — demo mode returns a canned
/// result; real mode calls the RandomForest models in
/// backend/app/ml/tabular/ via backend/app/api/recommend.py.
final recommendationRepositoryProvider = Provider<RecommendationRepository>((ref) {
  return RecommendationRepository(ref);
});

class RecommendationRepository {
  final Ref _ref;
  RecommendationRepository(this._ref);

  Future<CropRecommendation> recommendCrop({
    required double nitrogen,
    required double phosphorous,
    required double potassium,
    required double temperature,
    required double humidity,
    required double ph,
    required double rainfall,
  }) async {
    if (_ref.read(demoModeProvider)) {
      await Future.delayed(const Duration(milliseconds: 800));
      return MockData.cropRecommendation;
    }
    final api = await _ref.read(apiClientProvider.future);
    final response = await api.post<Map<String, dynamic>>(
      ApiConstants.recommendCrop,
      data: {
        'nitrogen': nitrogen,
        'phosphorous': phosphorous,
        'potassium': potassium,
        'temperature': temperature,
        'humidity': humidity,
        'ph': ph,
        'rainfall': rainfall,
      },
    );
    return CropRecommendation.fromJson(response.data!);
  }

  Future<FertilizerRecommendation> recommendFertilizer({
    required double temperature,
    required double humidity,
    required double moisture,
    required double nitrogen,
    required double potassium,
    required double phosphorous,
    required String soilType,
    required String cropType,
  }) async {
    if (_ref.read(demoModeProvider)) {
      await Future.delayed(const Duration(milliseconds: 800));
      return MockData.fertilizerRecommendation;
    }
    final api = await _ref.read(apiClientProvider.future);
    final response = await api.post<Map<String, dynamic>>(
      ApiConstants.recommendFertilizer,
      data: {
        'temperature': temperature,
        'humidity': humidity,
        'moisture': moisture,
        'nitrogen': nitrogen,
        'potassium': potassium,
        'phosphorous': phosphorous,
        'soil_type': soilType,
        'crop_type': cropType,
      },
    );
    return FertilizerRecommendation.fromJson(response.data!);
  }
}

/// Advisory agent chat (Phase 4) — real mode asks the LangGraph agent in
/// backend/app/agent/ (weather + soil + disease specialists, FAO-56
/// irrigation math, then an LLM synthesis + writer pass); demo mode returns
/// a canned example. One question can take longer than a typical API call
/// (multiple LLM calls chained server-side), hence the longer timeout below.
class AdvisoryTurn {
  final String question;
  final AdvisoryAnswer? answer; // null while this turn is in flight
  final String? error;
  const AdvisoryTurn({required this.question, this.answer, this.error});
}

class AdvisoryChatState {
  final List<AdvisoryTurn> turns;
  final bool sending;
  const AdvisoryChatState({this.turns = const [], this.sending = false});

  AdvisoryChatState copyWith({List<AdvisoryTurn>? turns, bool? sending}) {
    return AdvisoryChatState(turns: turns ?? this.turns, sending: sending ?? this.sending);
  }
}

final advisoryChatProvider = StateNotifierProvider<AdvisoryChatNotifier, AdvisoryChatState>((ref) {
  return AdvisoryChatNotifier(ref);
});

class AdvisoryChatNotifier extends StateNotifier<AdvisoryChatState> {
  final Ref _ref;
  AdvisoryChatNotifier(this._ref) : super(const AdvisoryChatState());

  Future<void> ask(String question) async {
    final q = question.trim();
    if (q.isEmpty || state.sending) return;

    state = state.copyWith(turns: [...state.turns, AdvisoryTurn(question: q)], sending: true);

    if (_ref.read(demoModeProvider)) {
      await Future.delayed(const Duration(milliseconds: 900));
      _replaceLast(answer: MockData.advisoryAnswer);
      state = state.copyWith(sending: false);
      return;
    }

    final farm = _ref.read(activeFarmProvider);
    if (farm == null || !farm.hasCoordinates) {
      _replaceLast(error: 'Add a location to your farm first (Farms → Edit → Latitude/Longitude).');
      state = state.copyWith(sending: false);
      return;
    }

    try {
      final api = await _ref.read(apiClientProvider.future);
      final response = await api.post<Map<String, dynamic>>(
        ApiConstants.advisoryAsk,
        data: {'farm_id': farm.id, 'question': q},
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );
      _replaceLast(answer: AdvisoryAnswer.fromJson(response.data!));
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['detail'] != null
          ? data['detail'].toString()
          : 'Could not reach the advisory agent. Please try again.';
      _replaceLast(error: message);
    } finally {
      state = state.copyWith(sending: false);
    }
  }

  void _replaceLast({AdvisoryAnswer? answer, String? error}) {
    if (state.turns.isEmpty) return;
    final turns = [...state.turns];
    final last = turns.last;
    turns[turns.length - 1] = AdvisoryTurn(question: last.question, answer: answer, error: error);
    state = state.copyWith(turns: turns);
  }

  void reset() => state = const AdvisoryChatState();
}

/// Government schemes — real mode calls the backend's real corpus (Phase 5
/// "Scheme RAG", see backend/app/rag/); demo mode uses MockData.
final governmentSchemesProvider = FutureProvider<List<GovernmentScheme>>((ref) async {
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.governmentSchemes;
  }
  final api = await ref.watch(apiClientProvider.future);
  final response = await api.get<List<dynamic>>(ApiConstants.schemes);
  return (response.data ?? [])
      .map((e) => GovernmentScheme.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Scheme search & filter state.
final schemeSearchProvider = StateProvider<String>((ref) => '');
final schemeCategoryProvider = StateProvider<String>((ref) => 'All');
final schemeStateProvider = StateProvider<String>((ref) => 'All States');

/// Semantic search results — real mode with a non-empty query only. Matches
/// on meaning, not just keyword overlap (e.g. "money if rain ruins my crop"
/// surfaces crop insurance with no shared words) — see backend/app/rag/.
final schemeSemanticResultsProvider = FutureProvider<List<GovernmentScheme>?>((ref) async {
  if (ref.watch(demoModeProvider)) return null;
  final query = ref.watch(schemeSearchProvider).trim();
  if (query.isEmpty) return null;
  final api = await ref.watch(apiClientProvider.future);
  final response = await api.get<List<dynamic>>(
    ApiConstants.schemeSearch,
    queryParameters: {'q': query, 'top_k': 10},
  );
  return (response.data ?? [])
      .map((e) => GovernmentScheme.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Bookmarked schemes.
final bookmarkedSchemesProvider = StateNotifierProvider<BookmarkedSchemesNotifier, Set<String>>((ref) {
  final storage = ref.watch(localStorageProvider);
  return BookmarkedSchemesNotifier(storage);
});

class BookmarkedSchemesNotifier extends StateNotifier<Set<String>> {
  final LocalStorage _storage;

  BookmarkedSchemesNotifier(this._storage)
      : super(_storage.getStringList(AppConstants.boxBookmarkedSchemes).toSet());

  void toggle(String schemeId) {
    if (state.contains(schemeId)) {
      state = {...state}..remove(schemeId);
    } else {
      state = {...state, schemeId};
    }
    _storage.setStringList(AppConstants.boxBookmarkedSchemes, state.toList());
  }

  bool isBookmarked(String schemeId) => state.contains(schemeId);
}

/// Filtered schemes: real mode with a non-empty search query uses the
/// semantic search endpoint; everything else uses local category/substring
/// filtering over the full list (same as before Phase 5).
final filteredSchemesProvider = Provider<AsyncValue<List<GovernmentScheme>>>((ref) {
  final search = ref.watch(schemeSearchProvider).toLowerCase();
  final category = ref.watch(schemeCategoryProvider);

  if (!ref.watch(demoModeProvider) && search.trim().isNotEmpty) {
    final semanticAsync = ref.watch(schemeSemanticResultsProvider);
    return semanticAsync.whenData((results) {
      final schemes = results ?? [];
      if (category == 'All') return schemes;
      return schemes.where((s) => s.category == category).toList();
    });
  }

  final schemesAsync = ref.watch(governmentSchemesProvider);
  return schemesAsync.whenData((schemes) {
    var filtered = schemes;
    if (category != 'All') {
      filtered = filtered.where((s) => s.category == category).toList();
    }
    if (search.isNotEmpty) {
      filtered = filtered
          .where((s) =>
              s.name.toLowerCase().contains(search) ||
              s.description.toLowerCase().contains(search))
          .toList();
    }
    return filtered;
  });
});

/// Notifications — real mode calls the backend; demo mode uses MockData.
/// Real notifications are written by the Phase 5 daily automation worker
/// (backend/app/workers/daily_advisory.py) — the 05:30 IST cron job, or the
/// manual trigger below (for demos/testing without waiting for the schedule).
final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  if (ref.watch(demoModeProvider)) {
    await Future.delayed(const Duration(milliseconds: 400));
    return MockData.notifications;
  }
  final api = await ref.watch(apiClientProvider.future);
  final response = await api.get<List<dynamic>>(ApiConstants.notifications);
  return (response.data ?? [])
      .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Manually runs the daily-advisory check right now (real mode only) —
/// POST /api/notifications/run-daily — instead of waiting for the scheduled
/// 05:30 IST job. Lets the automation actually be demonstrated on demand.
final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref);
});

class NotificationsRepository {
  final Ref _ref;
  NotificationsRepository(this._ref);

  Future<void> runDailyCheckNow() async {
    if (_ref.read(demoModeProvider)) return;
    final api = await _ref.read(apiClientProvider.future);
    await api.post<void>(
      ApiConstants.notificationsRunDaily,
      options: Options(receiveTimeout: const Duration(seconds: 45)),
    );
    _ref.invalidate(notificationsProvider);
  }
}

final selectedNotifCategoryProvider = StateProvider<String>((ref) => 'All');

final filteredNotificationsProvider = Provider<AsyncValue<List<NotificationItem>>>((ref) {
  final notifsAsync = ref.watch(notificationsProvider);
  final category = ref.watch(selectedNotifCategoryProvider);

  return notifsAsync.whenData((notifs) {
    if (category == 'All') return notifs;
    return notifs.where((n) => n.category == category).toList();
  });
});
