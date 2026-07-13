import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import '../../../models/room_model.dart';
import '../../projects/data/project_repository.dart';
import '../domain/quantity_calculator.dart';

class QuantitiesScreen extends ConsumerWidget {
  const QuantitiesScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(latestRoomProvider(projectId));

    return Scaffold(
      appBar: AppBar(title: const Text('Quantities & planning')),
      body: AsyncValueView<RoomModel?>(
        value: room,
        data: (r) {
          if (r == null) return const Center(child: Text('Scan a room first.'));
          final q = QuantityCalculator(r);
          final clearance = q.clearanceCheck();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Planning estimates only — verify on site. Not a '
                    'substitute for a professional take-off or building-code '
                    'compliance review.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SectionHeader('Areas'),
              _table(context, [
                ('Floor area', '${q.floorAreaM2.toStringAsFixed(2)} m²'),
                ('Ceiling area', '${q.ceilingAreaM2.toStringAsFixed(2)} m²'),
                ('Wall area (gross)',
                    '${q.wallAreaGrossM2.toStringAsFixed(2)} m²'),
                ('Wall area (net of openings)',
                    '${q.wallAreaNetM2.toStringAsFixed(2)} m²'),
                ('Perimeter',
                    '${r.dimensions.perimeterM.toStringAsFixed(2)} m'),
              ]),
              const SectionHeader('Material quantities'),
              _table(context, [
                ('Paint, walls only (2 coats +10%)',
                    '${q.paintLiters().toStringAsFixed(1)} L'),
                ('Paint incl. ceiling',
                    '${q.paintLiters(includeCeiling: true).toStringAsFixed(1)} L'),
                ('Tiles 60×60 (straight lay)', '${q.tileCount()} pcs'),
                ('Tiles 60×60 (diagonal)',
                    '${q.tileCount(diagonalLayout: true)} pcs'),
                ('Plank flooring (+8%)',
                    '${q.flooringM2().toStringAsFixed(2)} m²'),
                ('Skirting length',
                    '${q.skirtingLengthM().toStringAsFixed(2)} m'),
              ]),
              const SectionHeader('Clearance check (guidance)'),
              Card(
                child: ListTile(
                  leading: Icon(
                    clearance.ok
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    color: clearance.ok
                        ? Colors.green.shade600
                        : Theme.of(context).colorScheme.error,
                  ),
                  title: Text(clearance.note),
                ),
              ),
              const SectionHeader('Suggested construction sequence'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final (i, step)
                          in QuantityCalculator.constructionSequence.indexed)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                              radius: 12,
                              child: Text('${i + 1}',
                                  style: const TextStyle(fontSize: 11))),
                          title: Text(step),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _table(BuildContext context, List<(String, String)> rows) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: rows
                .map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(r.$1)),
                          Text(r.$2,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      );
}
