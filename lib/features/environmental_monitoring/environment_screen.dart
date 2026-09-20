import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../core/widgets/status_badge.dart';

/// Environmental Monitoring screen.
class EnvironmentScreen extends ConsumerWidget {
  const EnvironmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final envAsync = ref.watch(environmentDataProvider);
    final alertsAsync = ref.watch(environmentAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Environmental Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'View History',
            onPressed: () => context.push('/environment/history'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(environmentDataProvider);
          ref.invalidate(environmentAlertsProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: AsyncValueWidget(
          value: envAsync,
          onRetry: () => ref.invalidate(environmentDataProvider),
          data: (env) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Title ──
              Text('Environmental Conditions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Updated ${DateFormatter.timeAgo(env.updatedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // ── Condition Cards ──
              Row(
                children: [
                  Expanded(child: _EnvCard(icon: '🌡', label: 'Temperature', value: '${env.temperature.toInt()}°C', color: AppColors.chartTemperature)),
                  const SizedBox(width: 12),
                  Expanded(child: _EnvCard(icon: '💧', label: 'Humidity', value: '${env.humidity.toInt()}%', color: AppColors.chartMoisture)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _EnvCard(icon: '🌧', label: 'Rainfall', value: '${env.rainfall} mm', color: AppColors.skyBlue)),
                  const SizedBox(width: 12),
                  Expanded(child: _EnvCard(icon: '💨', label: 'Wind Speed', value: '${env.windSpeed.toInt()} km/h', color: AppColors.chartPotassium)),
                ],
              ),

              const SizedBox(height: 24),

              // ── Alerts Section ──
              Text('Environmental Alerts', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),

              AsyncValueWidget(
                value: alertsAsync,
                onRetry: () => ref.invalidate(environmentAlertsProvider),
                data: (alerts) => alerts.isEmpty
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.statusHealthy),
                              const SizedBox(width: 12),
                              Text('No active alerts', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: alerts.map((alert) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      alert.severity == 'danger' ? Icons.error_rounded : Icons.warning_rounded,
                                      color: alert.severity == 'danger' ? AppColors.statusCritical : AppColors.statusAttention,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(alert.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                    ),
                                    StatusBadge(
                                      status: alert.severity == 'danger' ? StatusLevel.critical : StatusLevel.attention,
                                      fontSize: 10,
                                      showIcon: false,
                                      label: alert.severity == 'danger' ? 'Critical' : 'Warning',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(alert.message, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 6),
                                Text(DateFormatter.timeAgo(alert.timestamp),
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () => context.push('/environment/history'),
                icon: const Icon(Icons.show_chart_rounded),
                label: const Text('View Environmental History'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnvCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _EnvCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
