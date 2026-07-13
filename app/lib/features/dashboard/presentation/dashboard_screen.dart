import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../../../models/project.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../projects/data/project_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${user?.displayName?.split(' ').first ?? 'there'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'AI Assistant',
            onPressed: () => context.push('/chat'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/scan'),
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('New scan'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(projectsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            const _DesignTipCard(),
            const SectionHeader('Quick stats'),
            projects.maybeWhen(
              data: (list) => _StatsRow(projects: list),
              orElse: () => const _StatsRow(projects: []),
            ),
            const SectionHeader('Recent projects'),
            AsyncValueView<List<Project>>(
              value: projects,
              onRetry: () => ref.invalidate(projectsProvider),
              data: (list) => list.isEmpty
                  ? const _EmptyState()
                  : Column(
                      children: [
                        for (final p in list) _ProjectTile(project: p),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignTipCard extends StatelessWidget {
  const _DesignTipCard();

  // v1 ships a static rotation; wire to Firestore designTips next sprint.
  static const _tips = [
    'Anchor a seating area with a rug at least 20 cm wider than the sofa.',
    'Layer three light sources per room: ambient, task, and accent.',
    'Keep walkways at least 75 cm clear for comfortable circulation.',
    'Warm white (2700K) suits bedrooms; neutral (4000K) suits kitchens.',
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[DateTime.now().day % _tips.length];
    return GlassCard(
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's design tip",
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(tip, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.projects});
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final analyzed = projects.where((p) => p.status != 'scanned').length;
    final favorites = projects.where((p) => p.isFavorite).length;
    Widget stat(String label, String value, IconData icon) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 6),
                  Text(value,
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(label,
                      style: Theme.of(context).textTheme.labelSmall,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
    return Row(children: [
      stat('Rooms', '${projects.length}', Icons.grid_view_rounded),
      const SizedBox(width: 8),
      stat('Analyzed', '$analyzed', Icons.insights_rounded),
      const SizedBox(width: 8),
      stat('Favorites', '$favorites', Icons.favorite_outline),
    ]);
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.meeting_room_outlined),
        ),
        title: Text(project.name),
        subtitle: Text('${project.roomType} · ${project.status}'),
        trailing: project.isFavorite
            ? const Icon(Icons.favorite, size: 18)
            : const Icon(Icons.chevron_right),
        onTap: () => context.push('/project/${project.id}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.view_in_ar_outlined,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text('No rooms yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Tap "New scan" to capture your first room.'),
        ],
      ),
    );
  }
}
