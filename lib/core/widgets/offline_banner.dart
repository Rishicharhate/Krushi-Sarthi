import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Banner that shows when the device is offline.
/// Displays last sync time and indicates cached data is being shown.
class OfflineBanner extends StatelessWidget {
  final DateTime? lastSyncTime;
  final bool isOffline;

  const OfflineBanner({
    super.key,
    this.lastSyncTime,
    this.isOffline = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statusAttention.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(
            color: AppColors.statusAttention.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppColors.statusAttention,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "You're offline",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.statusAttention,
                  ),
                ),
                Text(
                  lastSyncTime != null
                      ? 'Showing latest available data'
                      : 'No cached data available',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.statusAttention.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
