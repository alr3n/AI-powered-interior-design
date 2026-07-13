import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/presentation/auth_providers.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                title: Text(user.displayName ??
                    (user.isGuest ? 'Guest' : user.email ?? 'Account')),
                subtitle: Text(user.isGuest
                    ? 'Sign in with Google to keep your data'
                    : user.email ?? ''),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Theme'),
                  trailing: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined)),
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_outlined)),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => ref
                        .read(settingsProvider.notifier)
                        .setThemeMode(s.first),
                  ),
                ),
                ListTile(
                  title: const Text('Default budget tier'),
                  trailing: DropdownButton<String>(
                    value: settings.budgetTier,
                    underline: const SizedBox.shrink(),
                    items: AppConstants.budgetTiers
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => v == null
                        ? null
                        : ref
                            .read(settingsProvider.notifier)
                            .setBudgetTier(v),
                  ),
                ),
                ListTile(
                  title: const Text('Currency'),
                  trailing: Text(settings.currency),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 24),
          Text('SpaceSense AI v0.1.0',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
