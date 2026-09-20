import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/async_value_widget.dart';
import '../../core/widgets/status_badge.dart';

/// Crop Health / NDVI screen with circular indicator.
class CropHealthScreen extends ConsumerWidget {
  const CropHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cropAsync = ref.watch(cropHealthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Health'),
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'NDVI History',
            onPressed: () => context.push('/crop-health/history'),
          ),
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'Crop Map',
            onPressed: () => context.push('/crop-health/map'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cropHealthProvider);
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: AsyncValueWidget(
          value: cropAsync,
          onRetry: () => ref.invalidate(cropHealthProvider),
          data: (crop) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── NDVI Circular Indicator ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('NDVI Score', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      CircularPercentIndicator(
                        radius: 90,
                        lineWidth: 14,
                        percent: crop.ndvi.clamp(0, 1),
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              crop.ndvi.toStringAsFixed(2),
                              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            StatusBadge(
                              status: StatusBadgeHelpers.levelFromString(crop.healthStatus),
                              label: crop.healthStatus,
                            ),
                          ],
                        ),
                        progressColor: _ndviColor(crop.ndvi),
                        backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        circularStrokeCap: CircularStrokeCap.round,
                        animation: true,
                        animationDuration: 1200,
                      ),
                      const SizedBox(height: 20),
                      Text(crop.crop, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      Text(
                        'Satellite observation: ${DateFormatter.formatDate(crop.date)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── NDVI Details ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailRow(label: 'Current NDVI', value: crop.ndvi.toStringAsFixed(2)),
                      if (crop.previousNdvi != null) ...[
                        const Divider(height: 20),
                        _DetailRow(label: 'Previous NDVI', value: crop.previousNdvi!.toStringAsFixed(2)),
                      ],
                      if (crop.ndviChange != null) ...[
                        const Divider(height: 20),
                        _DetailRow(
                          label: 'Change',
                          value: '${crop.ndviChange! > 0 ? '+' : ''}${crop.ndviChange!.toStringAsFixed(2)}',
                          valueColor: crop.ndviChange! >= 0 ? AppColors.statusHealthy : AppColors.statusCritical,
                        ),
                      ],
                      const Divider(height: 20),
                      _DetailRow(label: 'Health Status', value: crop.healthStatus),
                      const Divider(height: 20),
                      _DetailRow(label: 'Crop', value: crop.crop),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── NDVI Scale Reference ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NDVI Scale', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: AppColors.ndviGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0.0', style: theme.textTheme.bodySmall),
                          Text('0.5', style: theme.textTheme.bodySmall),
                          Text('1.0', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Stressed', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.statusCritical)),
                          Text('Moderate', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.statusAttention)),
                          Text('Healthy', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.statusHealthy)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: () => context.push('/crop-health/history'),
                icon: const Icon(Icons.trending_up_rounded),
                label: const Text('View NDVI Trend'),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Color _ndviColor(double ndvi) {
    if (ndvi >= 0.6) return AppColors.statusHealthy;
    if (ndvi >= 0.3) return AppColors.statusAttention;
    return AppColors.statusCritical;
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: valueColor)),
      ],
    );
  }
}
