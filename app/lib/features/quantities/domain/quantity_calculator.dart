import 'dart:math' as math;

import '../../../core/constants/app_constants.dart';
import '../../../models/room_model.dart';

/// Civil-engineering quantity take-offs. Pure functions — fully unit-testable.
/// All results are planning estimates, NOT a substitute for a professional
/// take-off or building-code compliance review.
class QuantityCalculator {
  const QuantityCalculator(this.room);
  final RoomModel room;

  double get floorAreaM2 => room.floorAreaM2;
  double get ceilingAreaM2 => room.ceilingAreaM2;
  double get wallAreaGrossM2 => room.wallAreaGrossM2;
  double get wallAreaNetM2 => room.wallAreaNetM2;

  /// Liters of paint for walls (+ ceiling optionally), 2 coats + 10% waste.
  double paintLiters({bool includeCeiling = false, int? coats}) {
    final area = wallAreaNetM2 + (includeCeiling ? ceilingAreaM2 : 0);
    return area /
        AppConstants.paintCoverageM2PerLiter *
        (coats ?? AppConstants.paintCoats) *
        AppConstants.paintWasteFactor;
  }

  /// Tile count for the floor given a tile size in meters.
  int tileCount({double tileWidthM = 0.6, double tileLengthM = 0.6,
      bool diagonalLayout = false}) {
    final tileArea = tileWidthM * tileLengthM;
    if (tileArea <= 0) return 0;
    final waste = diagonalLayout
        ? AppConstants.tileWasteFactorDiagonal
        : AppConstants.tileWasteFactor;
    return (floorAreaM2 / tileArea * waste).ceil();
  }

  /// Plank/roll flooring quantity in m² including waste.
  double flooringM2() => floorAreaM2 * AppConstants.flooringWasteFactor;

  /// Skirting/baseboard length ≈ perimeter minus door widths.
  double skirtingLengthM() {
    final doors = room.openings
        .where((o) => o.type == 'door')
        .fold(0.0, (s, o) => s + o.widthM);
    return math.max(0, room.dimensions.perimeterM - doors);
  }

  /// Guidance-level clearance check: rough free-width heuristic.
  /// Compares free floor share against the walkway minimum over the shorter axis.
  ClearanceCheck clearanceCheck() {
    final shortSide =
        math.min(room.dimensions.lengthM, room.dimensions.widthM);
    final freeShare = room.freeFloorPct;
    final estFreeWidth = shortSide * freeShare;
    final ok = estFreeWidth >= AppConstants.minWalkwayM;
    return ClearanceCheck(
      ok: ok,
      note: ok
          ? 'Estimated circulation width ~${estFreeWidth.toStringAsFixed(2)} m '
              'meets the ${AppConstants.minWalkwayM} m guidance minimum.'
          : 'Estimated circulation width ~${estFreeWidth.toStringAsFixed(2)} m '
              'is below the ${AppConstants.minWalkwayM} m guidance minimum — '
              'consider slimmer or fewer furniture pieces.',
    );
  }

  /// Suggested renovation sequence (planning guidance).
  static const constructionSequence = [
    'Clear the room and protect fixed elements',
    'Demolition / removals (old flooring, fixtures)',
    'Electrical rough-in (new outlets, lighting points)',
    'Wall repairs and surface preparation',
    'Ceiling works and paint',
    'Wall paint or finishes (2 coats, 4h+ between)',
    'Flooring installation',
    'Skirting, trims, and doors',
    'Light fixtures and hardware',
    'Deep clean, then furniture and styling',
  ];
}

class ClearanceCheck {
  const ClearanceCheck({required this.ok, required this.note});
  final bool ok;
  final String note;
}
