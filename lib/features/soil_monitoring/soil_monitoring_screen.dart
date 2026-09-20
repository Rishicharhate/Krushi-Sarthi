import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/async_value_widget.dart';

/// Soil Monitoring screen — displays current readings and insights.
class SoilMonitoringScreen extends ConsumerWidget {
  const SoilMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final soilAsync = ref.watch(soilDataProvider);
    final insightsAsync = ref.watch(soilInsightsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Soil Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'View History',
            onPressed: () => context.push('/monitoring/history'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(soilDataProvider);
          ref.invalidate(soilInsightsProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: AsyncValueWidget(
          value: soilAsync,
          onRetry: () => ref.invalidate(soilDataProvider),
          data: (soil) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Overall Status ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.earthBrown.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.terrain_rounded, color: AppColors.earthBrown, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Overall Soil Health', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              'Updated ${DateFormatter.timeAgo(soil.updatedAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        status: StatusBadgeHelpers.levelFromString(soil.overallStatus ?? 'Healthy'),
                        label: soil.overallStatus,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Moisture Card ──
              _SoilParamCard(
                icon: Icons.water_drop_rounded,
                iconColor: AppColors.chartMoisture,
                title: 'Soil Moisture',
                value: '${soil.moisture.toInt()}%',
                status: soil.moistureStatus ?? 'Good',
                updatedAt: soil.updatedAt,
              ),

              // ── Temperature Card ──
              _SoilParamCard(
                icon: Icons.thermostat_rounded,
                iconColor: AppColors.chartTemperature,
                title: 'Soil Temperature',
                value: '${soil.temperature.toInt()}°C',
                status: 'Normal',
                updatedAt: soil.updatedAt,
              ),

              // ── pH Card ──
              _SoilParamCard(
                icon: Icons.science_rounded,
                iconColor: AppColors.chartPh,
                title: 'Soil pH',
                value: soil.ph.toStringAsFixed(1),
                status: soil.phStatus ?? 'Normal',
                updatedAt: soil.updatedAt,
              ),

              const SizedBox(height: 8),

              // ── NPK Card ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.chartNitrogen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.eco_rounded, color: AppColors.chartNitrogen, size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text('NPK Levels', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _NpkRow(label: 'Nitrogen', value: '${soil.nitrogen.toInt()} mg/kg', color: AppColors.chartNitrogen),
                      const Divider(height: 20),
                      _NpkRow(label: 'Phosphorus', value: '${soil.phosphorus.toInt()} mg/kg', color: AppColors.chartPhosphorus),
                      const Divider(height: 20),
                      _NpkRow(label: 'Potassium', value: '${soil.potassium.toInt()} mg/kg', color: AppColors.chartPotassium),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Soil Insights ──
              Text('Soil Insights', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              AsyncValueWidget(
                value: insightsAsync,
                onRetry: () => ref.invalidate(soilInsightsProvider),
                data: (insights) => Column(
                  children: insights.map((insight) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            insight.type == 'success' ? Icons.check_circle_rounded
                                : insight.type == 'warning' ? Icons.warning_rounded
                                : Icons.info_rounded,
                            color: insight.type == 'success' ? AppColors.statusHealthy
                                : insight.type == 'warning' ? AppColors.statusAttention
                                : AppColors.skyBlue,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(insight.message, style: theme.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
                ),
              ),

              const SizedBox(height: 16),

              // ── View History Button ──
              OutlinedButton.icon(
                onPressed: () => context.push('/monitoring/history'),
                icon: const Icon(Icons.show_chart_rounded),
                label: const Text('View Soil History'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoilParamCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String status;
  final DateTime updatedAt;

  const _SoilParamCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.status,
    required this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    'Updated ${DateFormatter.timeAgo(updatedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            StatusBadge(
              status: StatusBadgeHelpers.levelFromString(status),
              label: status,
              fontSize: 11,
            ),
          ],
        ),
      ),
    );
  }
}

class _NpkRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NpkRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
        ),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
