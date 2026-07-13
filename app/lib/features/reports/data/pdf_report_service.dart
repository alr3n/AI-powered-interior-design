import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../models/analysis_result.dart';
import '../../../models/design_concept.dart';
import '../../../models/room_model.dart';
import '../../cost/domain/cost_estimator.dart';
import '../../quantities/domain/quantity_calculator.dart';

/// Composes the professional project report locally with the `pdf` package —
/// no server round-trip, works offline once data is loaded.
class PdfReportService {
  final _php = NumberFormat.currency(symbol: 'PHP ', decimalDigits: 0);

  Future<Uint8List> build({
    required String projectName,
    required RoomModel room,
    AnalysisResult? analysis,
    List<DesignConcept> designs = const [],
    CostBreakdown? cost,
  }) async {
    final q = QuantityCalculator(room);
    final doc = pw.Document();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('SpaceSense AI · page ${ctx.pageNumber}/${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
      ),
      build: (context) => [
        // ---- Header --------------------------------------------------
        pw.Text(projectName,
            style: const pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.Text(
            'Room analysis report · ${DateFormat.yMMMMd().format(DateTime.now())}',
            style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.Divider(),

        // ---- Room summary -------------------------------------------
        _h('Room summary'),
        _table([
          ['Room type', room.roomType],
          ['Dimensions',
            '${room.dimensions.lengthM.toStringAsFixed(2)} x '
                '${room.dimensions.widthM.toStringAsFixed(2)} x '
                '${room.dimensions.heightM.toStringAsFixed(2)} m '
                '(${room.dimensionSource.name})'],
          ['Floor area', '${q.floorAreaM2.toStringAsFixed(2)} m2'],
          ['Wall area (net)', '${q.wallAreaNetM2.toStringAsFixed(2)} m2'],
          ['Furniture detected', '${room.furniture.length} items'],
          ['Free floor', '${(room.freeFloorPct * 100).round()}%'],
        ]),

        // ---- Furniture ------------------------------------------------
        if (room.furniture.isNotEmpty) ...[
          _h('Furniture inventory'),
          _table([
            ['Item', 'Category', 'Confidence'],
            ...room.furniture.map((f) =>
                [f.label, f.category, '${(f.confidence * 100).round()}%']),
          ], header: true),
        ],

        // ---- Materials -----------------------------------------------
        if (room.materials.isNotEmpty) ...[
          _h('Detected materials'),
          _table([
            ['Surface', 'Material', 'Confidence'],
            ...room.materials.map((m) =>
                [m.surface, m.material, '${(m.confidence * 100).round()}%']),
          ], header: true),
        ],

        // ---- Analysis -------------------------------------------------
        if (analysis != null) ...[
          _h('AI interior analysis — score ${analysis.overallScore}/100'),
          _table([
            ['Category', 'Score'],
            ...analysis.categoryScores.entries.map((e) => [
                  AnalysisResult.categoryLabels[e.key] ?? e.key,
                  '${e.value}/100'
                ]),
          ], header: true),
          _h2('Strengths'),
          ...analysis.strengths.map(_bullet),
          _h2('Weaknesses'),
          ...analysis.weaknesses.map(_bullet),
          _h2('Recommendations'),
          ...analysis.recommendations.map((r) => _bullet(
              '[${r.priority.toUpperCase()}] ${r.title} — ${r.detail}'
              '${r.estCost != null ? ' (~${_php.format(r.estCost)})' : ''}')),
        ],

        // ---- Quantities ----------------------------------------------
        _h('Quantity estimates (guidance only)'),
        _table([
          ['Paint, walls 2 coats', '${q.paintLiters().toStringAsFixed(1)} L'],
          ['Tiles 60x60', '${q.tileCount()} pcs'],
          ['Flooring (+8%)', '${q.flooringM2().toStringAsFixed(2)} m2'],
          ['Skirting', '${q.skirtingLengthM().toStringAsFixed(2)} m'],
        ]),
        pw.Text(
            'Estimates for planning only — verify on site. Not a code-compliance review.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),

        // ---- Cost ------------------------------------------------------
        if (cost != null) ...[
          _h('Cost estimate — ${cost.tier} tier'),
          _table([
            ['Category', 'Qty', 'Total'],
            ...cost.lines.map((l) => [
                  l.category,
                  '${l.qty.toStringAsFixed(1)} ${l.unit}',
                  _php.format(l.total)
                ]),
            ['Materials', '', _php.format(cost.materials)],
            ['Labor', '', _php.format(cost.labor)],
            ['Grand total (+${cost.contingencyPct.toStringAsFixed(0)}%)', '',
              _php.format(cost.grandTotal)],
          ], header: true),
        ],

        // ---- Designs ----------------------------------------------------
        if (designs.isNotEmpty) ...[
          _h('Design concepts'),
          ...designs.map((d) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(d.style,
                        style: const pw.TextStyle(
                            fontSize: 13, fontWeight: pw.FontWeight.bold)),
                    pw.Text(d.mood, style: const pw.TextStyle(fontSize: 10)),
                    pw.Row(
                        children: d.palette
                            .take(6)
                            .map((p) => pw.Container(
                                  width: 16,
                                  height: 16,
                                  margin: const pw.EdgeInsets.only(
                                      right: 4, top: 4),
                                  color: PdfColor.fromHex(p.hex),
                                ))
                            .toList()),
                    pw.Text(
                        'Budget ~${_php.format(d.budgetTotal)} · ${d.difficulty} · '
                        '${d.maintenance} maintenance',
                        style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              )),
        ],

        // ---- Checklist ---------------------------------------------------
        _h('Renovation checklist'),
        ...QuantityCalculator.constructionSequence
            .map((s) => _bullet(s, box: true)),
      ],
    ));

    return doc.save();
  }

  pw.Widget _h(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(text,
            style: const pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _h2(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
        child: pw.Text(text,
            style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _bullet(String text, {bool box = false}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2, left: 4),
        child: pw.Text('${box ? '[ ]' : '-'} $text',
            style: const pw.TextStyle(fontSize: 10)),
      );

  pw.Widget _table(List<List<String>> rows, {bool header = false}) =>
      pw.TableHelper.fromTextArray(
        data: rows,
        headerCount: header ? 1 : 0,
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerStyle:
            const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      );
}
