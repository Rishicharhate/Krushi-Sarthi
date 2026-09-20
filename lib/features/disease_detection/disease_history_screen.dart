import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/async_value_widget.dart';

/// Disease scan history screen.
class DiseaseHistoryScreen extends ConsumerWidget {
  const DiseaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(diseaseHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Disease Scan History')),
      body: AsyncValueWidget(
        value: historyAsync,
        onRetry: () => ref.invalidate(diseaseHistoryProvider),
        isEmpty: (data) => data.isEmpty,
        emptyMessage: 'No disease scans yet.\nUse the Disease AI tab to scan a leaf.',
        data: (history) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          itemBuilder: (context, index) {
            final result = history[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: result.isHealthy
                            ? AppColors.statusHealthyBg
                            : AppColors.statusCriticalBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        result.isHealthy ? Icons.check_circle_rounded : Icons.bug_report_rounded,
                        color: result.isHealthy ? AppColors.statusHealthy : AppColors.statusCritical,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.disease,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(result.crop ?? 'Unknown Crop',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          Text(DateFormatter.formatDate(result.scannedAt),
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${result.confidence.toStringAsFixed(1)}%',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
