import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';

/// Scheme detail screen with full information.
class SchemeDetailScreen extends ConsumerWidget {
  final String schemeId;

  const SchemeDetailScreen({super.key, required this.schemeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final schemesAsync = ref.watch(governmentSchemesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scheme Details')),
      body: schemesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (schemes) {
          final scheme = schemes.where((s) => s.id == schemeId).firstOrNull;
          if (scheme == null) {
            return const Center(child: Text('Scheme not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Header ──
              Text(scheme.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
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
                  const SizedBox(width: 8),
                  Text('Updated ${DateFormatter.formatDate(scheme.updatedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),

              const SizedBox(height: 24),

              _DetailSection(title: 'Overview', content: scheme.description),
              _DetailSection(title: 'Eligibility', content: scheme.eligibility),
              _DetailSection(title: 'Benefits', content: scheme.benefits),

              if (scheme.documents.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Required Documents',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...scheme.documents.map((doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.description_outlined, size: 18, color: AppColors.primaryGreen),
                      const SizedBox(width: 10),
                      Expanded(child: Text(doc, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                )),
              ],

              if (scheme.applicationProcess != null)
                _DetailSection(title: 'How to Apply', content: scheme.applicationProcess!),

              if (scheme.applicationUrl != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    final url = Uri.parse(scheme.applicationUrl!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Apply / Official Website'),
                ),
              ],

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final String content;

  const _DetailSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const Divider(height: 16),
          Text(content, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
        ],
      ),
    );
  }
}
