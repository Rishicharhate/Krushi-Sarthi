import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/async_value_widget.dart';

/// Government Schemes screen with search & filters.
class SchemesScreen extends ConsumerWidget {
  const SchemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final filteredAsync = ref.watch(filteredSchemesProvider);
    final selectedCategory = ref.watch(schemeCategoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Government Schemes')),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (v) => ref.read(schemeSearchProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Search schemes...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),

          // ── Category Chips ──
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: AppConstants.schemeCategories.map((cat) {
                final isSelected = cat == selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => ref.read(schemeCategoryProvider.notifier).state = cat,
                    selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primaryGreen : null,
                      fontWeight: isSelected ? FontWeight.w600 : null,
                      fontSize: 13,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // ── Scheme List ──
          Expanded(
            child: AsyncValueWidget(
              value: filteredAsync,
              onRetry: () => ref.invalidate(governmentSchemesProvider),
              isEmpty: (data) => data.isEmpty,
              emptyMessage: 'No schemes found matching your criteria.',
              data: (schemes) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: schemes.length,
                itemBuilder: (context, index) {
                  final scheme = schemes[index];
                  final isBookmarked = ref.watch(bookmarkedSchemesProvider).contains(scheme.id);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/schemes/${scheme.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(scheme.name,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                    color: isBookmarked ? AppColors.harvestGold : null,
                                  ),
                                  onPressed: () => ref.read(bookmarkedSchemesProvider.notifier).toggle(scheme.id),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scheme.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(scheme.category,
                                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
                                ),
                                Text('Updated ${DateFormatter.formatDate(scheme.updatedAt)}',
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('View Details →',
                                  style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
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
}
