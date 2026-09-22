import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/offline_banner.dart';

/// Main farmer dashboard with summary cards and quick actions.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(farmerProfileProvider);
    final activeFarm = ref.watch(activeFarmProvider);
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.whenOrNull(data: (v) => !v) ?? false;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(soilDataProvider);
            ref.invalidate(environmentDataProvider);
            ref.invalidate(cropHealthProvider);
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            slivers: [
              // ── Offline Banner ──
              if (isOffline)
                const SliverToBoxAdapter(child: OfflineBanner()),

              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${DateFormatter.greeting()} 👋',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  profileAsync.whenOrNull(data: (p) => p.name) ?? 'Farmer',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined),
                                onPressed: () => context.push('/notifications'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_outline_rounded),
                                onPressed: () => context.push('/profile'),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Farm Selector ──
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push('/farms'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryGreen.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.grass_rounded, size: 20, color: AppColors.primaryGreen),
                              const SizedBox(width: 8),
                              Text(
                                activeFarm?.name ?? 'My Farm',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 20, color: AppColors.primaryGreen),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Summary Cards ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _SoilSummaryCard(ref: ref),
                      const SizedBox(height: 12),
                      _EnvironmentSummaryCard(ref: ref),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _CropHealthCard(ref: ref)),
                          const SizedBox(width: 12),
                          Expanded(child: _DiseaseDetectionCard()),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.05, end: 0),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── Quick Actions ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Quick Actions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _QuickActionsGrid(),
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DASHBOARD CARDS
// ══════════════════════════════════════════════════════════════

class _SoilSummaryCard extends StatelessWidget {
  final WidgetRef ref;
  const _SoilSummaryCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soilAsync = ref.watch(soilDataProvider);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/monitoring'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: soilAsync.when(
            loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Unable to load soil data', style: theme.textTheme.bodyMedium),
            data: (soil) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.earthBrown.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.terrain_rounded, color: AppColors.earthBrown, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text('Soil Health', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    StatusBadge(
                      status: StatusBadgeHelpers.levelFromString(soil.overallStatus ?? 'Healthy'),
                      label: soil.overallStatus ?? 'Healthy',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _MetricTile(label: 'Moisture', value: '${soil.moisture.toInt()}%'),
                    _MetricTile(label: 'pH', value: soil.ph.toStringAsFixed(1)),
                    _MetricTile(label: 'Temp', value: '${soil.temperature.toInt()}°C'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View Details',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primaryGreen),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnvironmentSummaryCard extends StatelessWidget {
  final WidgetRef ref;
  const _EnvironmentSummaryCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final envAsync = ref.watch(environmentDataProvider);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/environment'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: envAsync.when(
            loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Unable to load environment data', style: theme.textTheme.bodyMedium),
            data: (env) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.skyBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_rounded, color: AppColors.skyBlue, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text('Environment', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _MetricTile(label: 'Temp', value: '${env.temperature.toInt()}°C', icon: '🌡'),
                    _MetricTile(label: 'Humidity', value: '${env.humidity.toInt()}%', icon: '💧'),
                    _MetricTile(label: 'Rain', value: '${env.rainfall}mm', icon: '🌧'),
                    _MetricTile(label: 'Wind', value: '${env.windSpeed.toInt()}km/h', icon: '💨'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CropHealthCard extends StatelessWidget {
  final WidgetRef ref;
  const _CropHealthCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cropAsync = ref.watch(cropHealthProvider);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/crop-health'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: cropAsync.when(
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => const SizedBox(height: 120, child: Center(child: Icon(Icons.error_outline))),
            data: (crop) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.satellite_alt_rounded, color: AppColors.primaryGreen, size: 20),
                ),
                const SizedBox(height: 12),
                Text('Crop Health', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('NDVI', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  crop.ndvi.toStringAsFixed(2),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 4),
                StatusBadge(
                  status: StatusBadgeHelpers.levelFromString(crop.healthStatus),
                  label: crop.healthStatus,
                  fontSize: 11,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiseaseDetectionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/disease'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.harvestGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_rounded, color: AppColors.harvestGold, size: 20),
              ),
              const SizedBox(height: 12),
              Text('AI Disease', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Upload a leaf image to check crop health.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.document_scanner_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Scan Leaf',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String? icon;

  const _MetricTile({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          if (icon != null) Text(icon!, style: const TextStyle(fontSize: 16)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// QUICK ACTIONS GRID
// ══════════════════════════════════════════════════════════════

class _QuickActionsGrid extends StatelessWidget {
  static const _actions = [
    (icon: Icons.terrain_rounded, label: 'Soil', color: AppColors.earthBrown, route: '/monitoring'),
    (icon: Icons.cloud_rounded, label: 'Environment', color: AppColors.skyBlue, route: '/environment'),
    (icon: Icons.satellite_alt_rounded, label: 'Crop Health', color: AppColors.primaryGreen, route: '/crop-health'),
    (icon: Icons.psychology_rounded, label: 'Disease AI', color: AppColors.harvestGold, route: '/disease'),
    (icon: Icons.eco_rounded, label: 'Recommend', color: AppColors.primaryGreen, route: '/recommend'),
    (icon: Icons.chat_rounded, label: 'Ask KrushiSarthi', color: AppColors.skyBlue, route: '/advisory'),
    (icon: Icons.storefront_rounded, label: 'Mandi Prices', color: AppColors.harvestGold, route: '/market'),
    (icon: Icons.account_balance_rounded, label: 'Schemes', color: AppColors.earthBrownLight, route: '/schemes'),
    (icon: Icons.notifications_rounded, label: 'Alerts', color: AppColors.statusAttention, route: '/notifications'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: _actions.length,
      itemBuilder: (context, index) {
        final action = _actions[index];
        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (action.route == '/environment' ||
                  action.route == '/notifications' ||
                  action.route == '/recommend' ||
                  action.route == '/advisory' ||
                  action.route == '/market') {
                context.push(action.route);
              } else {
                context.go(action.route);
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(action.icon, color: action.color, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
