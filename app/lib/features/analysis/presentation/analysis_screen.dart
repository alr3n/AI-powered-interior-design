import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failures.dart';
import '../../../core/widgets/common.dart';
import '../../../models/analysis_result.dart';
import '../../../services/gemini_client.dart';
import '../../projects/data/project_repository.dart';

/// Runs (or re-runs) the 13-category Gemini analysis and renders scores.
class AnalysisController
    extends AutoDisposeFamilyAsyncNotifier<AnalysisResult?, String> {
  @override
  Future<AnalysisResult?> build(String projectId) async {
    // Show the stored analysis if one exists; user can regenerate.
    final stream = ref.watch(latestAnalysisProvider(projectId));
    return stream.valueOrNull;
  }

  Future<void> run() async {
    final projectId = arg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(projectRepositoryProvider);
      if (repo == null) throw const AuthFailure();
      final room = ref.read(latestRoomProvider(projectId)).valueOrNull;
      if (room == null) {
        throw const ValidationFailure('Scan the room before analyzing.');
      }
      final result = await ref.read(geminiClientProvider).analyzeRoom(room);
      await repo.saveAnalysis(projectId, result, room.version);
      await repo.setStatus(projectId, 'analyzed');
      return result;
    });
  }
}

final analysisControllerProvider = AutoDisposeAsyncNotifierProviderFamily<
    AnalysisController, AnalysisResult?, String>(AnalysisController.new);

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisControllerProvider(projectId));

    return Scaffold(
      appBar: AppBar(title: const Text('Interior analysis')),
      body: AsyncValueView<AnalysisResult?>(
        value: analysis,
        onRetry: () =>
            ref.read(analysisControllerProvider(projectId).notifier).run(),
        data: (result) => result == null
            ? _EmptyAnalysis(
                onRun: () => ref
                    .read(analysisControllerProvider(projectId).notifier)
                    .run())
            : _AnalysisView(
                result: result,
                onRerun: () => ref
                    .read(analysisControllerProvider(projectId).notifier)
                    .run()),
      ),
    );
  }
}

class _EmptyAnalysis extends StatelessWidget {
  const _EmptyAnalysis({required this.onRun});
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_rounded,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('No analysis yet.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRun,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Analyze with Gemini'),
          ),
        ],
      ),
    );
  }
}

class _AnalysisView extends StatelessWidget {
  const _AnalysisView({required this.result, required this.onRerun});
  final AnalysisResult result;
  final VoidCallback onRerun;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
            child: ScoreRing(
                score: result.overallScore, size: 140, label: 'Interior score')),
        const SectionHeader('Category scores'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: result.categoryScores.entries.map((e) {
                final label =
                    AnalysisResult.categoryLabels[e.key] ?? e.key;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(width: 150, child: Text(label)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                              value: e.value / 100, minHeight: 8),
                        ),
                      ),
                      SizedBox(
                          width: 36,
                          child: Text('${e.value}',
                              textAlign: TextAlign.end,
                              style:
                                  Theme.of(context).textTheme.labelLarge)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SectionHeader('Strengths'),
        _BulletCard(items: result.strengths, icon: Icons.check_circle_outline),
        const SectionHeader('Weaknesses'),
        _BulletCard(items: result.weaknesses, icon: Icons.error_outline),
        const SectionHeader('Recommendations'),
        ...result.recommendations.map((r) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: _PriorityDot(priority: r.priority),
                title: Text(r.title),
                subtitle: Text(r.detail),
                trailing: r.estCost != null
                    ? Text('₱${r.estCost!.toStringAsFixed(0)}')
                    : null,
              ),
            )),
        if (result.assumptions.isNotEmpty) ...[
          const SectionHeader('Assumptions'),
          _BulletCard(items: result.assumptions, icon: Icons.info_outline),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRerun,
          icon: const Icon(Icons.refresh),
          label: const Text('Re-analyze'),
        ),
      ],
    );
  }
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({required this.items, required this.icon});
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: items
              .map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s)),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});
  final String priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'high' => Theme.of(context).colorScheme.error,
      'medium' => Colors.amber.shade700,
      _ => Colors.green.shade600,
    };
    return CircleAvatar(radius: 6, backgroundColor: color);
  }
}
