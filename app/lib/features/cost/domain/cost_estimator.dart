import '../../../models/room_model.dart';
import '../../quantities/domain/quantity_calculator.dart';

/// Deterministic cost estimation from quantities × regional unit rates.
/// Rates default to Philippine market values (PHP); production reads them
/// from Firestore `costCatalog/{region}` so they update without a release.
class CostEstimator {
  const CostEstimator({this.rates = philippineRates});
  final Map<String, Map<String, double>> rates;

  /// PHP unit rates by budget tier. Sources: indicative PH market ranges;
  /// keep fresh via costCatalog.
  static const philippineRates = <String, Map<String, double>>{
    // materials per unit
    'paint_liter': {'low': 400, 'medium': 650, 'premium': 950, 'luxury': 1500},
    'tile_m2': {'low': 450, 'medium': 800, 'premium': 1500, 'luxury': 3500},
    'flooring_m2': {'low': 600, 'medium': 1200, 'premium': 2500, 'luxury': 5000},
    'lighting_fixture': {'low': 800, 'medium': 2500, 'premium': 6000, 'luxury': 15000},
    'cabinet_lm': {'low': 6000, 'medium': 12000, 'premium': 22000, 'luxury': 45000},
    'decor_lump': {'low': 3000, 'medium': 8000, 'premium': 20000, 'luxury': 60000},
    // labor per unit
    'labor_paint_m2': {'low': 60, 'medium': 90, 'premium': 120, 'luxury': 180},
    'labor_tile_m2': {'low': 350, 'medium': 450, 'premium': 600, 'luxury': 800},
    'labor_electrical_point': {'low': 800, 'medium': 1200, 'premium': 1800, 'luxury': 2500},
  };

  double _rate(String key, String tier) => rates[key]?[tier] ?? 0;

  CostBreakdown estimate(RoomModel room, {required String tier,
      int lightingPoints = 4, double cabinetLinearM = 2.0}) {
    final q = QuantityCalculator(room);
    final lines = <CostLine>[
      CostLine('Paint (walls, 2 coats)', q.paintLiters(), 'L',
          _rate('paint_liter', tier),
          labor: q.wallAreaNetM2 * _rate('labor_paint_m2', tier)),
      CostLine('Flooring', q.flooringM2(), 'm²', _rate('flooring_m2', tier),
          labor: q.floorAreaM2 * _rate('labor_tile_m2', tier)),
      CostLine('Lighting fixtures', lightingPoints.toDouble(), 'pc',
          _rate('lighting_fixture', tier),
          labor:
              lightingPoints * _rate('labor_electrical_point', tier)),
      CostLine('Cabinetry', cabinetLinearM, 'lm', _rate('cabinet_lm', tier)),
      CostLine('Decoration allowance', 1, 'lot', _rate('decor_lump', tier)),
    ];
    final materials = lines.fold(0.0, (s, l) => s + l.materialTotal);
    final labor = lines.fold(0.0, (s, l) => s + l.labor);
    const contingencyPct = 10.0;
    final grand = (materials + labor) * (1 + contingencyPct / 100);
    return CostBreakdown(
      tier: tier,
      lines: lines,
      materials: materials,
      labor: labor,
      contingencyPct: contingencyPct,
      grandTotal: grand,
    );
  }
}

class CostLine {
  const CostLine(this.category, this.qty, this.unit, this.unitCost,
      {this.labor = 0});
  final String category;
  final double qty;
  final String unit;
  final double unitCost;
  final double labor;

  double get materialTotal => qty * unitCost;
  double get total => materialTotal + labor;
}

class CostBreakdown {
  const CostBreakdown({
    required this.tier,
    required this.lines,
    required this.materials,
    required this.labor,
    required this.contingencyPct,
    required this.grandTotal,
  });

  final String tier;
  final List<CostLine> lines;
  final double materials;
  final double labor;
  final double contingencyPct;
  final double grandTotal;
}
