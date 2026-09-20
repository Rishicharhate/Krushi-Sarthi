import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';

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
                      color: _confidenceColor(result.confidence).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Confidence: ${result.confidence.toStringAsFixed(1)}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _confidenceColor(result.confidence),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

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

  Color _confidenceColor(double confidence) {
    if (confidence >= 90) return AppColors.statusHealthy;
    if (confidence >= 70) return AppColors.statusAttention;
    return AppColors.statusCritical;
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
