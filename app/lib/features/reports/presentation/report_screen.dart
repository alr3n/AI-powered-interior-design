import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/widgets/common.dart';
import '../../../models/room_model.dart';
import '../../cost/domain/cost_estimator.dart';
import '../../projects/data/project_repository.dart';
import '../../settings/presentation/settings_providers.dart';
import '../data/pdf_report_service.dart';

class ReportScreen extends ConsumerWidget {
  const ReportScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final room = ref.watch(latestRoomProvider(projectId));

    return Scaffold(
      appBar: AppBar(title: const Text('PDF report')),
      body: AsyncValueView<RoomModel?>(
        value: room,
        data: (r) {
          if (r == null) return const Center(child: Text('Scan a room first.'));
          final analysis =
              ref.watch(latestAnalysisProvider(projectId)).valueOrNull;
          final designs =
              ref.watch(designsProvider(projectId)).valueOrNull ?? [];
          final tier = ref.watch(settingsProvider).budgetTier;
          final cost = const CostEstimator().estimate(r, tier: tier);

          // Live preview + native print/share sheet via `printing`.
          return PdfPreview(
            canChangePageFormat: false,
            pdfFileName:
                'spacesense_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
            build: (_) => PdfReportService().build(
              projectName: 'SpaceSense project',
              room: r,
              analysis: analysis,
              designs: designs,
              cost: cost,
            ),
          );
        },
      ),
    );
  }
}
