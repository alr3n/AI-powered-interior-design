import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../../../models/room_model.dart';
import '../data/project_repository.dart';

/// Project hub: room summary + entry points to every analysis feature.
class ProjectScreen extends ConsumerWidget {
  const ProjectScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(latestRoomProvider(projectId));

    return Scaffold(
      appBar: AppBar(title: const Text('Room overview')),
      body: AsyncValueView<RoomModel?>(
        value: room,
        onRetry: () => ref.invalidate(latestRoomProvider(projectId)),
        data: (r) {
          if (r == null) {
            return const Center(child: Text('No room model yet — scan first.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RoomSummaryCard(room: r),
              const SectionHeader('Analyze'),
              _FeatureGrid(projectId: projectId),
              if (r.assumptions.isNotEmpty) ...[
                const SectionHeader('AI assumptions'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: r.assumptions
                          .map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text('• $a'),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RoomSummaryCard extends StatelessWidget {
  const _RoomSummaryCard({required this.room});
  final RoomModel room;

  @override
  Widget build(BuildContext context) {
    final d = room.dimensions;
    final sourceLabel = switch (room.dimensionSource) {
      DimensionSource.ar => 'AR measured',
      DimensionSource.manual => 'Measured',
      DimensionSource.ai => 'AI estimated',
    };
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(room.roomType,
                      style: Theme.of(context).textTheme.titleLarge)),
              Chip(label: Text(sourceLabel), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              '${d.lengthM.toStringAsFixed(1)} × ${d.widthM.toStringAsFixed(1)} m'
              ' · height ${d.heightM.toStringAsFixed(1)} m'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _metric(context, 'Floor', '${room.floorAreaM2.toStringAsFixed(1)} m²'),
              _metric(context, 'Walls (net)',
                  '${room.wallAreaNetM2.toStringAsFixed(1)} m²'),
              _metric(context, 'Furniture', '${room.furniture.length} items'),
              _metric(context, 'Free floor',
                  '${(room.freeFloorPct * 100).round()}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      );
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('AI analysis', Icons.insights_rounded, 'analysis'),
      ('Design styles', Icons.palette_outlined, 'designs'),
      ('Cost estimate', Icons.payments_outlined, 'cost'),
      ('Quantities', Icons.straighten, 'quantities'),
      ('PDF report', Icons.picture_as_pdf_outlined, 'report'),
    ];
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: items
          .map((i) => Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => context.push('/project/$projectId/${i.$3}'),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(i.$2,
                            color: Theme.of(context).colorScheme.primary),
                        Text(i.$1,
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
