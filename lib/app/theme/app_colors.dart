import 'package:flutter/material.dart';

/// Agriculture-inspired color palette for KrushiSarthi.
/// Uses earthy greens, warm browns, and sky blues to create
/// a natural, farmer-friendly visual identity.
class AppColors {
  AppColors._();

  // ── Primary: Deep Agricultural Green ──
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color primaryGreenLight = Color(0xFF4CAF50);
  static const Color primaryGreenDark = Color(0xFF1B5E20);

  // ── Secondary: Earth Brown ──
  static const Color earthBrown = Color(0xFF6D4C41);
  static const Color earthBrownLight = Color(0xFF8D6E63);
  static const Color earthBrownDark = Color(0xFF4E342E);

  // ── Tertiary: Sky Blue ──
  static const Color skyBlue = Color(0xFF42A5F5);
  static const Color skyBlueLight = Color(0xFF90CAF9);
  static const Color skyBlueDark = Color(0xFF1565C0);

  // ── Accent: Harvest Gold ──
  static const Color harvestGold = Color(0xFFF9A825);
  static const Color harvestGoldLight = Color(0xFFFFD54F);

  // ── Semantic Status Colors ──
  static const Color statusHealthy = Color(0xFF43A047);
  static const Color statusAttention = Color(0xFFFFA726);
  static const Color statusCritical = Color(0xFFE53935);

  // ── Status backgrounds (translucent) ──
  static const Color statusHealthyBg = Color(0x1A43A047);
  static const Color statusAttentionBg = Color(0x1AFFA726);
  static const Color statusCriticalBg = Color(0x1AE53935);

  // ── Light Theme Surfaces ──
  static const Color lightBackground = Color(0xFFF5F7F0);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF0F4E8);
  static const Color lightOnSurface = Color(0xFF1A1C18);
  static const Color lightOnSurfaceVariant = Color(0xFF44483E);
  static const Color lightOutline = Color(0xFF74796D);
  static const Color lightOutlineVariant = Color(0xFFC4C8BB);

  // ── Dark Theme Surfaces ──
  static const Color darkBackground = Color(0xFF1A1C18);
  static const Color darkSurface = Color(0xFF1E201B);
  static const Color darkSurfaceVariant = Color(0xFF2D3028);
  static const Color darkOnSurface = Color(0xFFE2E3DC);
  static const Color darkOnSurfaceVariant = Color(0xFFC4C8BB);
  static const Color darkOutline = Color(0xFF8E9286);
  static const Color darkOutlineVariant = Color(0xFF44483E);

  // ── Chart Colors ──
  static const Color chartMoisture = Color(0xFF42A5F5);
  static const Color chartTemperature = Color(0xFFEF5350);
  static const Color chartPh = Color(0xFF66BB6A);
  static const Color chartNitrogen = Color(0xFF5C6BC0);
  static const Color chartPhosphorus = Color(0xFFFF7043);
  static const Color chartPotassium = Color(0xFFAB47BC);
  static const Color chartNdvi = Color(0xFF26A69A);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, Color(0xFF43A047)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient soilGradient = LinearGradient(
    colors: [earthBrown, Color(0xFF795548)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient skyGradient = LinearGradient(
    colors: [skyBlue, Color(0xFF64B5F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ndviGradient = LinearGradient(
    colors: [Color(0xFFE53935), Color(0xFFFFA726), Color(0xFF43A047)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient splashGradient = LinearGradient(
    colors: [primaryGreenDark, primaryGreen, Color(0xFF388E3C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
