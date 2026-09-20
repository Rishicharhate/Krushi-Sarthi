import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/widgets/async_value_widget.dart';

/// Farmer profile screen.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(farmerProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: AsyncValueWidget(
        value: profileAsync,
        onRetry: () => ref.invalidate(farmerProfileProvider),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Avatar ──
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
                    child: Text(
                      profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'F',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(profile.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(profile.mobile, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Personal Info ──
            Text('Personal Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ProfileRow(icon: Icons.person_rounded, label: 'Name', value: profile.name),
                    const Divider(height: 20),
                    _ProfileRow(icon: Icons.phone_rounded, label: 'Mobile', value: profile.mobile),
                    const Divider(height: 20),
                    _ProfileRow(icon: Icons.location_on_rounded, label: 'Village', value: profile.village ?? 'Not set'),
                    const Divider(height: 20),
                    _ProfileRow(icon: Icons.map_rounded, label: 'District', value: profile.district ?? 'Not set'),
                    const Divider(height: 20),
                    _ProfileRow(icon: Icons.flag_rounded, label: 'State', value: profile.state ?? 'Not set'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Quick Links ──
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.grass_rounded, color: AppColors.primaryGreen),
                    title: const Text('My Farms'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/farms'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.settings_rounded, color: AppColors.earthBrown),
                    title: const Text('Settings'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/settings'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded, color: AppColors.skyBlue),
                    title: const Text('About'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/about'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryGreen),
        const SizedBox(width: 12),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const Spacer(),
        Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
