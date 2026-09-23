import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/models/disease_result.dart';

/// Disease result screen showing AI analysis output.
class DiseaseResultScreen extends ConsumerWidget {
  const DiseaseResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(diseaseDetectionProvider);
    final result = state.result;

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analysis Result')),
        body: const Center(child: Text('No result available')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('AI Analysis Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Result Header ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: result.isHealthy
                          ? AppColors.statusHealthyBg
                          : AppColors.statusCriticalBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      result.isHealthy ? Icons.check_circle_rounded : Icons.warning_rounded,
                      size: 40,
                      color: result.isHealthy ? AppColors.statusHealthy : AppColors.statusCritical,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (result.crop != null)
                    Text('Crop: ${result.crop}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(
                    result.disease,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _certaintyColor(result).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _certaintyLabel(result),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _certaintyColor(result),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Model score: ${result.confidence.toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (result.caution != null) ...[
            Card(
              color: AppColors.statusAttentionBg,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_rounded, color: AppColors.statusAttention),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(result.caution!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Disease Information ──
          if (result.description != null) ...[
            _Section(
              title: 'Disease Information',
              icon: Icons.info_outline_rounded,
              child: Text(result.description!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
            ),
          ],

          if (result.symptoms != null) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Symptoms',
              icon: Icons.local_hospital_rounded,
              child: Text(result.symptoms!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
            ),
          ],

          if (result.recommendation != null) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Recommendation',
              icon: Icons.lightbulb_outline_rounded,
              child: Text(result.recommendation!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
            ),
          ],

          if (result.alternatives.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: 'Other Possibilities',
              icon: Icons.compare_arrows_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final alt in result.alternatives) ...[
                    Text(
                      '${alt.disease} (${alt.confidence.toStringAsFixed(0)}%)',
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (alt.symptoms != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        child: Text(alt.symptoms!, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: () {
              ref.read(diseaseDetectionProvider.notifier).reset();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Analyze Another Image'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Uses the backend's certainty tier, which is calibrated for this model
  /// (see backend/app/ml/disease/cascade.py). The raw softmax % is not: the
  /// model averages ~53% even when correct, so fixed 70/90% cut-offs would
  /// paint almost every correct diagnosis red.
  String _certaintyLabel(DiseaseResult result) {
    switch (_tier(result)) {
      case 'high':
        return 'High confidence';
      case 'medium':
        return 'Likely match';
      default:
        return 'Low confidence';
    }
  }

  Color _certaintyColor(DiseaseResult result) {
    switch (_tier(result)) {
      case 'high':
        return AppColors.statusHealthy;
      case 'medium':
        return AppColors.statusAttention;
      default:
        return AppColors.statusCritical;
    }
  }

  // History rows and mock data carry no tier; fall back to the backend's
  // thresholds (40% = high, 30% = medium).
  String _tier(DiseaseResult result) {
    if (result.certainty != null) return result.certainty!;
    if (result.confidence >= 40) return 'high';
    if (result.confidence >= 30) return 'medium';
    return 'low';
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
