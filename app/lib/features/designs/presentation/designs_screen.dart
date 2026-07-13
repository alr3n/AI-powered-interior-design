import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/widgets/common.dart';
import '../../../models/design_concept.dart';
import '../../../services/gemini_client.dart';
import '../../projects/data/project_repository.dart';
import '../../settings/presentation/settings_providers.dart';

/// Generates a style concept via Gemini and stores it under the project.
class DesignGenController extends AutoDisposeFamilyAsyncNotifier<void, String> {
  @override
  Future<void> build(String projectId) async {}

  Future<void> generate(String style) async {
    final projectId = arg;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(projectRepositoryProvider);
      if (repo == null) throw const AuthFailure();
      final room = ref.read(latestRoomProvider(projectId)).valueOrNull;
      if (room == null) {
        throw const ValidationFailure('Scan the room before generating designs.');
      }
      final tier = ref.read(settingsProvider).budgetTier;
      final concept = await ref
          .read(geminiClientProvider)
          .generateDesign(room, style: style, tier: tier);
      await repo.saveDesign(projectId, concept);
      await repo.setStatus(projectId, 'designed');
    });
  }
}

final designGenProvider =
    AutoDisposeAsyncNotifierProviderFamily<DesignGenController, void, String>(
        DesignGenController.new);

class DesignsScreen extends ConsumerWidget {
  const DesignsScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final designs = ref.watch(designsProvider(projectId));
    final gen = ref.watch(designGenProvider(projectId));

    ref.listen(designGenProvider(projectId), (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.error.toString())));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Design concepts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader('Generate a style'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.designStyles
                .map((s) => ActionChip(
                      label: Text(s),
                      avatar: gen.isLoading
                          ? null
                          : const Icon(Icons.auto_awesome, size: 16),
                      onPressed: gen.isLoading
                          ? null
                          : () => ref
                              .read(designGenProvider(projectId).notifier)
                              .generate(s),
                    ))
                .toList(),
          ),
          if (gen.isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: Column(children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Designing your room…'),
              ])),
            ),
          const SectionHeader('Concepts'),
          AsyncValueView<List<DesignConcept>>(
            value: designs,
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('Pick a style above to start.')))
                : Column(
                    children:
                        list.map((d) => _ConceptCard(concept: d)).toList()),
          ),
        ],
      ),
    );
  }
}

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({required this.concept});
  final DesignConcept concept;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(concept.style,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
            '₱${concept.budgetTotal.toStringAsFixed(0)} · ${concept.difficulty} · ${concept.maintenance} maintenance'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(concept.mood),
          const SizedBox(height: 12),
          Row(
            children: concept.palette
                .take(6)
                .map((p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Tooltip(
                        message: '${p.role} ${p.hex}',
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: hexColor(p.hex),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    Theme.of(context).colorScheme.outlineVariant),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          _kv(context, 'Flooring', concept.flooring),
          _kv(context, 'Walls', concept.wallFinish),
          _kv(context, 'Materials', concept.materials.join(', ')),
          _kv(context, 'Lighting', concept.lighting.join(', ')),
          _kv(context, 'Decor', concept.decor.join(', ')),
          const SizedBox(height: 8),
          Text('Furniture', style: Theme.of(context).textTheme.labelLarge),
          ...concept.furniture.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(
                        f.priority == 'core'
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(f.item)),
                    if (f.estPrice != null)
                      Text('₱${f.estPrice!.toStringAsFixed(0)}'),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) => v.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                    text: '$k: ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: v),
              ],
            ),
          ),
        );
}
