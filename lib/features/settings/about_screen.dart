import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// About screen with app information.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),

          // ── Logo ──
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.eco_rounded, size: 52, color: AppColors.primaryGreen),
            ),
          ),

          const SizedBox(height: 20),

          Center(
            child: Text(
              AppConstants.appName,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Center(
            child: Text(
              AppConstants.appSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Center(
            child: Text(
              'Version ${AppConstants.appVersion}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),

          const SizedBox(height: 32),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About This Project',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(
                    'KrushiSarthi is a Smart AI-Based Farmer Crop & Soil Management System designed to transform traditional farming into intelligent, data-driven precision agriculture.\n\n'
                    'The app provides farmers with one unified platform for real-time soil monitoring, environmental tracking, satellite-based crop health analysis, AI-powered disease detection, and government scheme information.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Technology Stack',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _TechRow(label: 'Frontend', value: 'Flutter / Dart'),
                  _TechRow(label: 'Backend', value: 'FastAPI / Python'),
                  _TechRow(label: 'AI/ML', value: 'TensorFlow / CNN'),
                  _TechRow(label: 'Satellite', value: 'Sentinel-2 / NDVI'),
                  _TechRow(label: 'IoT', value: 'Soil Sensors'),
                  _TechRow(label: 'Database', value: 'PostgreSQL / Firebase'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Project Type',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    'Final Year Engineering Project',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Text(
              '© 2026 KrushiSarthi',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TechRow extends StatelessWidget {
  final String label;
  final String value;

  const _TechRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
