import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/widgets/async_value_widget.dart';

/// Farm management screen — list, select, add farms.
class FarmManagementScreen extends ConsumerWidget {
  const FarmManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final farmsAsync = ref.watch(farmsProvider);
    final activeFarm = ref.watch(activeFarmProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Farms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/farms/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Farm'),
      ),
      body: AsyncValueWidget(
        value: farmsAsync,
        onRetry: () => ref.invalidate(farmsProvider),
        isEmpty: (data) => data.isEmpty,
        emptyMessage: 'No farms added yet.\nTap + to add your first farm.',
        data: (farms) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: farms.length,
          itemBuilder: (context, index) {
            final farm = farms[index];
            final isActive = activeFarm?.id == farm.id;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: isActive
                    ? const BorderSide(color: AppColors.primaryGreen, width: 2)
                    : BorderSide.none,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => ref.read(selectedFarmIdProvider.notifier).select(farm.id),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.grass_rounded, color: AppColors.primaryGreen, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(farm.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                Text('${farm.area} ${farm.areaUnit}  •  ${farm.crop}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.statusHealthyBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('Active',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.statusHealthy,
                                    fontWeight: FontWeight.w600,
                                  )),
                            ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                context.push('/farms/edit/${farm.id}');
                              } else if (v == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete farm?'),
                                    content: Text('This removes "${farm.name}" and its saved data.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(dialogContext).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await ref.read(farmsRepositoryProvider).deleteFarm(farm.id);
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                      if (farm.location != null || farm.soilType != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (farm.location != null)
                              _InfoChip(icon: Icons.location_on_outlined, label: farm.location!),
                            if (farm.soilType != null)
                              _InfoChip(icon: Icons.terrain_outlined, label: farm.soilType!),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
