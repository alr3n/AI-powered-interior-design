import 'package:flutter_test/flutter_test.dart';
import 'package:spacesense_ai/features/cost/domain/cost_estimator.dart';
import 'package:spacesense_ai/features/quantities/domain/quantity_calculator.dart';
import 'package:spacesense_ai/models/room_model.dart';

RoomModel _room() => const RoomModel(
      id: 'v1',
      projectId: 'p1',
      version: 1,
      roomType: 'bedroom',
      dimensionSource: DimensionSource.manual,
      dimensions: RoomDimensions(lengthM: 4.2, widthM: 3.5, heightM: 2.7),
      openings: [
        Opening(type: 'door', widthM: 0.9, heightM: 2.1),
        Opening(type: 'window', widthM: 1.5, heightM: 1.2),
      ],
      furniture: [
        FurnitureItem(
            category: 'bed', label: 'Queen bed', lengthM: 2.0, widthM: 1.5),
      ],
    );

void main() {
  group('QuantityCalculator', () {
    final q = QuantityCalculator(_room());

    test('areas', () {
      expect(q.floorAreaM2, closeTo(14.70, 0.001));
      expect(q.ceilingAreaM2, closeTo(14.70, 0.001));
      // perimeter 15.4 × 2.7 = 41.58 gross
      expect(q.wallAreaGrossM2, closeTo(41.58, 0.001));
      // minus door 1.89 and window 1.8 → 37.89
      expect(q.wallAreaNetM2, closeTo(37.89, 0.001));
    });

    test('paint liters: net/10 × 2 coats × 1.1', () {
      expect(q.paintLiters(), closeTo(37.89 / 10 * 2 * 1.1, 0.001));
    });

    test('tile count 60×60 straight: ceil(14.7/0.36 × 1.10) = 45', () {
      expect(q.tileCount(), 45);
    });

    test('flooring +8%', () {
      expect(q.flooringM2(), closeTo(14.70 * 1.08, 0.001));
    });

    test('skirting = perimeter − doors', () {
      expect(q.skirtingLengthM(), closeTo(15.4 - 0.9, 0.001));
    });

    test('clearance check runs and reports', () {
      final c = q.clearanceCheck();
      expect(c.note, isNotEmpty);
    });
  });

  group('CostEstimator', () {
    test('grand total = (materials + labor) × 1.10, monotonic across tiers',
        () {
      final room = _room();
      const estimator = CostEstimator();
      final low = estimator.estimate(room, tier: 'low');
      final medium = estimator.estimate(room, tier: 'medium');
      final luxury = estimator.estimate(room, tier: 'luxury');

      expect(low.grandTotal,
          closeTo((low.materials + low.labor) * 1.10, 0.01));
      expect(medium.grandTotal, greaterThan(low.grandTotal));
      expect(luxury.grandTotal, greaterThan(medium.grandTotal));
      expect(low.lines, isNotEmpty);
    });
  });

  group('RoomModel', () {
    test('json round-trip preserves core fields', () {
      final r = _room();
      final restored = RoomModel.fromJson('v1', 'p1', r.toJson());
      expect(restored.dimensions.lengthM, r.dimensions.lengthM);
      expect(restored.furniture.length, 1);
      expect(restored.openings.length, 2);
      expect(restored.dimensionSource, DimensionSource.manual);
    });

    test('free floor percentage', () {
      final r = _room();
      // bed 3 m² over 14.7 m² floor → ~79.6% free
      expect(r.freeFloorPct, closeTo(1 - 3.0 / 14.7, 0.001));
    });
  });
}
