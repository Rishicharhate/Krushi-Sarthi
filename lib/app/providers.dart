import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import '../core/mock/mock_data.dart';
import '../core/storage/local_storage.dart';
import '../shared/models/soil_data.dart';
import '../shared/models/environment_data.dart';
import '../shared/models/crop_health.dart';
import '../shared/models/disease_result.dart';
import '../shared/models/government_scheme.dart';
import '../shared/models/farm.dart';
import '../shared/models/farmer_profile.dart';
import '../shared/models/notification_item.dart';

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
// FEATURE PROVIDERS (Demo Mode — uses MockData)
// ══════════════════════════════════════════════════════════════

/// Farmer profile.
final farmerProfileProvider = FutureProvider<FarmerProfile>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return MockData.farmerProfile;
});

/// Farms list.
final farmsProvider = FutureProvider<List<Farm>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return MockData.farms;
});

/// Active farm selection.
final activeFarmProvider = StateProvider<Farm?>((ref) {
  return MockData.farms.firstWhere((f) => f.isActive, orElse: () => MockData.farms.first);
});

/// Current soil data.
final soilDataProvider = FutureProvider<SoilData>((ref) async {
  await Future.delayed(const Duration(milliseconds: 600));
  return MockData.soilData;
});

/// Soil history — parameter-dependent.
final selectedSoilParamProvider = StateProvider<String>((ref) => 'Moisture');
final selectedSoilPeriodProvider = StateProvider<String>((ref) => AppConstants.period7d);

final soilHistoryProvider = FutureProvider<List<SoilHistoryPoint>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  final param = ref.watch(selectedSoilParamProvider);
  return switch (param) {
    'pH' => MockData.soilPhHistory(),
    'Temperature' => MockData.soilTemperatureHistory(),
    _ => MockData.soilMoistureHistory(),
  };
});

/// Soil insights.
final soilInsightsProvider = FutureProvider<List<SoilInsight>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return MockData.soilInsights;
});

/// Current environment data.
final environmentDataProvider = FutureProvider<EnvironmentData>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return MockData.environmentData;
});

/// Environment history.
final selectedEnvParamProvider = StateProvider<String>((ref) => 'Temperature');
final selectedEnvPeriodProvider = StateProvider<String>((ref) => AppConstants.period7d);

final environmentHistoryProvider = FutureProvider<List<EnvironmentHistoryPoint>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  final param = ref.watch(selectedEnvParamProvider);
  return switch (param) {
    'Humidity' => MockData.humidityHistory(),
    _ => MockData.temperatureHistory(),
  };
});

/// Environment alerts.
final environmentAlertsProvider = FutureProvider<List<EnvironmentAlert>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return MockData.environmentAlerts;
});

/// Crop health / NDVI.
final cropHealthProvider = FutureProvider<CropHealth>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return MockData.cropHealth;
});

/// NDVI history.
final ndviHistoryProvider = FutureProvider<List<NdviHistoryPoint>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return MockData.ndviHistory;
});

/// Disease detection state.
final diseaseDetectionProvider =
    StateNotifierProvider<DiseaseDetectionNotifier, DiseaseDetectionState>((ref) {
  return DiseaseDetectionNotifier();
});

class DiseaseDetectionNotifier extends StateNotifier<DiseaseDetectionState> {
  DiseaseDetectionNotifier() : super(const DiseaseDetectionState());

  void selectImage(String path) {
    state = DiseaseDetectionState(
      status: DiseaseDetectionStatus.imageSelected,
      imagePath: path,
    );
  }

  Future<void> analyzeImage() async {
    state = state.copyWith(status: DiseaseDetectionStatus.uploading, uploadProgress: 0.0);

    // Simulate upload progress
    for (var i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      state = state.copyWith(uploadProgress: i / 10);
    }

    state = state.copyWith(status: DiseaseDetectionStatus.analyzing);
    await Future.delayed(const Duration(seconds: 2));

    state = state.copyWith(
      status: DiseaseDetectionStatus.success,
      result: MockData.diseaseResult,
    );
  }

  void reset() {
    state = const DiseaseDetectionState();
  }
}

/// Disease history.
final diseaseHistoryProvider = FutureProvider<List<DiseaseResult>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 300));
  return MockData.diseaseHistory;
});

/// Government schemes.
final governmentSchemesProvider = FutureProvider<List<GovernmentScheme>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  return MockData.governmentSchemes;
});

/// Scheme search & filter state.
final schemeSearchProvider = StateProvider<String>((ref) => '');
final schemeCategoryProvider = StateProvider<String>((ref) => 'All');
final schemeStateProvider = StateProvider<String>((ref) => 'All States');

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

/// Filtered schemes.
final filteredSchemesProvider = Provider<AsyncValue<List<GovernmentScheme>>>((ref) {
  final schemesAsync = ref.watch(governmentSchemesProvider);
  final search = ref.watch(schemeSearchProvider).toLowerCase();
  final category = ref.watch(schemeCategoryProvider);

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

/// Notifications.
final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 400));
  return MockData.notifications;
});

final selectedNotifCategoryProvider = StateProvider<String>((ref) => 'All');

final filteredNotificationsProvider = Provider<AsyncValue<List<NotificationItem>>>((ref) {
  final notifsAsync = ref.watch(notificationsProvider);
  final category = ref.watch(selectedNotifCategoryProvider);

  return notifsAsync.whenData((notifs) {
    if (category == 'All') return notifs;
    return notifs.where((n) => n.category == category).toList();
  });
});
