import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/common.dart';
import '../../../models/room_model.dart';
import '../../projects/data/project_repository.dart';
import '../domain/cost_estimator.dart';

final _php = NumberFormat.currency(symbol: '₱', decimalDigits: 0);

class CostScreen extends ConsumerStatefulWidget {
  const CostScreen({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<CostScreen> createState() => _CostScreenState();
}

class _CostScreenState extends ConsumerState<CostScreen> {
  String _tier = 'medium';

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(latestRoomProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(title: const Text('Cost estimate')),
      body: AsyncValueView<RoomModel?>(
        value: room,
        data: (r) {
          if (r == null) return const Center(child: Text('Scan a room first.'));
          final breakdown =
              const CostEstimator().estimate(r, tier: _tier);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                segments: AppConstants.budgetTiers
                    .map((t) => ButtonSegment(
                        value: t,
                        label: Text(t[0].toUpperCase() + t.substring(1))))
                    .toList(),
                selected: {_tier},
                onSelectionChanged: (s) => setState(() => _tier = s.first),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    Text('Estimated total',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(_php.format(breakdown.grandTotal),
                        style: Theme.of(context).textTheme.displaySmall),
                    Text(
                        'incl. ${breakdown.contingencyPct.toStringAsFixed(0)}% contingency',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              const SectionHeader('Breakdown'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      for (final line in breakdown.lines)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(line.category),
                                    Text(
                                      '${line.qty.toStringAsFixed(1)} ${line.unit}'
                                      ' × ${_php.format(line.unitCost)}'
                                      '${line.labor > 0 ? ' + labor ${_php.format(line.labor)}' : ''}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                              Text(_php.format(line.total),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall),
                            ],
                          ),
                        ),
                      const Divider(),
                      _totalRow(context, 'Materials', breakdown.materials),
                      _totalRow(context, 'Labor', breakdown.labor),
                      _totalRow(context, 'Grand total', breakdown.grandTotal,
                          bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rates are indicative Philippine market values. Get at least '
                'three contractor quotes before committing.',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _totalRow(BuildContext context, String label, double value,
          {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: bold
                        ? Theme.of(context).textTheme.titleMedium
                        : null)),
            Text(_php.format(value),
                style: bold
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      );
}
