import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Settings screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final demoMode = ref.watch(demoModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ── Appearance ──
          _SectionTitle('Appearance'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_rounded),
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between light and dark theme'),
            value: isDark,
            onChanged: (_) => ref.read(themeModeProvider.notifier).toggleDarkMode(),
          ),

          const Divider(),

          // ── App Mode ──
          _SectionTitle('App Mode'),
          SwitchListTile(
            secondary: const Icon(Icons.science_rounded),
            title: const Text('Demo Mode'),
            subtitle: const Text('Show sample data without backend connection'),
            value: demoMode,
            onChanged: (_) => ref.read(demoModeProvider.notifier).toggle(),
          ),

          const Divider(),

          // ── Data ──
          _SectionTitle('Data'),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Clear Cache'),
            subtitle: const Text('Remove all locally cached data'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Cache'),
                  content: const Text('This will remove all locally cached data. Are you sure?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cache cleared')),
                        );
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(),

          // ── Info ──
          _SectionTitle('Information'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About'),
            subtitle: Text('${AppConstants.appName} v${AppConstants.appVersion}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
