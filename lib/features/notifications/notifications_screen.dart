import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/async_value_widget.dart';

/// Notifications screen with category filters.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filteredAsync = ref.watch(filteredNotificationsProvider);
    final selectedCategory = ref.watch(selectedNotifCategoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Column(
        children: [
          // ── Category Tabs ──
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: AppConstants.notificationCategories.map((cat) {
                final isSelected = cat == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => ref.read(selectedNotifCategoryProvider.notifier).state = cat,
                    selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : null),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // ── Notifications List ──
          Expanded(
            child: AsyncValueWidget(
              value: filteredAsync,
              onRetry: () => ref.invalidate(notificationsProvider),
              isEmpty: (data) => data.isEmpty,
              emptyMessage: 'No notifications yet.',
              data: (notifications) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: notif.isRead ? null : AppColors.primaryGreen.withValues(alpha: 0.04),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _categoryColor(notif.category).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_categoryIcon(notif.category),
                                size: 20, color: _categoryColor(notif.category)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(notif.title,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700,
                                          )),
                                    ),
                                    if (!notif.isRead)
                                      Container(
                                        width: 8, height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primaryGreen,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(notif.message,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                const SizedBox(height: 6),
                                Text(DateFormatter.timeAgo(notif.timestamp),
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String category) => switch (category) {
    'Soil Alerts' => Icons.terrain_rounded,
    'Environmental Alerts' => Icons.cloud_rounded,
    'Crop Health Alerts' => Icons.satellite_alt_rounded,
    'Disease Alerts' => Icons.bug_report_rounded,
    'Scheme Updates' => Icons.account_balance_rounded,
    _ => Icons.notifications_rounded,
  };

  Color _categoryColor(String category) => switch (category) {
    'Soil Alerts' => AppColors.earthBrown,
    'Environmental Alerts' => AppColors.skyBlue,
    'Crop Health Alerts' => AppColors.primaryGreen,
    'Disease Alerts' => AppColors.statusCritical,
    'Scheme Updates' => AppColors.harvestGold,
    _ => AppColors.primaryGreen,
  };
}
