import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Satellite / Crop Health Map screen.
/// Displays NDVI satellite image when available from backend.
class CropMapScreen extends StatelessWidget {
  const CropMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Crop Health Map')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Map Placeholder ──
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen.withValues(alpha: 0.15),
                    AppColors.primaryGreenLight.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.satellite_alt_rounded, size: 64,
                        color: AppColors.primaryGreen.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'Satellite NDVI Map',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Map will be displayed when\nsatellite data is available from backend',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _InfoRow(label: 'NDVI', value: '0.72'),
                  const Divider(height: 20),
                  _InfoRow(label: 'Status', value: 'Healthy'),
                  const Divider(height: 20),
                  _InfoRow(label: 'Last Satellite Update', value: '19 Sep 2026'),
                  const Divider(height: 20),
                  _InfoRow(label: 'Data Source', value: 'Sentinel-2'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
