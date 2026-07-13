import 'dart:math' as math;

/// Where dimension numbers came from — AR measurement is authoritative.
enum DimensionSource { ar, ai, manual }

class RoomDimensions {
  const RoomDimensions(
      {required this.lengthM, required this.widthM, required this.heightM});

  final double lengthM;
  final double widthM;
  final double heightM;

  double get floorAreaM2 => lengthM * widthM;
  double get perimeterM => 2 * (lengthM + widthM);

  Map<String, dynamic> toJson() =>
      {'lengthM': lengthM, 'widthM': widthM, 'heightM': heightM};

  factory RoomDimensions.fromJson(Map<String, dynamic> j) => RoomDimensions(
        lengthM: (j['lengthM'] as num).toDouble(),
        widthM: (j['widthM'] as num).toDouble(),
        heightM: (j['heightM'] as num).toDouble(),
      );
}

class Opening {
  const Opening({required this.type, required this.widthM, required this.heightM});

  final String type; // door | window
  final double widthM;
  final double heightM;

  double get areaM2 => widthM * heightM;

  Map<String, dynamic> toJson() =>
      {'type': type, 'widthM': widthM, 'heightM': heightM};

  factory Opening.fromJson(Map<String, dynamic> j) => Opening(
        type: j['type'] as String? ?? 'door',
        widthM: (j['widthM'] as num? ?? 0.9).toDouble(),
        heightM: (j['heightM'] as num? ?? 2.1).toDouble(),
      );
}

class FurnitureItem {
  const FurnitureItem({
    required this.category,
    required this.label,
    this.lengthM,
    this.widthM,
    this.heightM,
    this.confidence = 0,
  });

  final String category;
  final String label;
  final double? lengthM;
  final double? widthM;
  final double? heightM;
  final double confidence;

  double get footprintM2 => (lengthM ?? 0) * (widthM ?? 0);

  Map<String, dynamic> toJson() => {
        'category': category,
        'label': label,
        if (lengthM != null) 'lengthM': lengthM,
        if (widthM != null) 'widthM': widthM,
        if (heightM != null) 'heightM': heightM,
        'confidence': confidence,
      };

  factory FurnitureItem.fromJson(Map<String, dynamic> j) {
    final dims = j['approxDims'] as Map<String, dynamic>? ?? j;
    return FurnitureItem(
      category: j['category'] as String? ?? 'other',
      label: j['label'] as String? ?? 'Item',
      lengthM: (dims['l'] as num? ?? dims['lengthM'] as num?)?.toDouble(),
      widthM: (dims['w'] as num? ?? dims['widthM'] as num?)?.toDouble(),
      heightM: (dims['h'] as num? ?? dims['heightM'] as num?)?.toDouble(),
      confidence: (j['confidence'] as num? ?? 0).toDouble(),
    );
  }
}

class MaterialDetection {
  const MaterialDetection(
      {required this.surface, required this.material, required this.confidence});

  final String surface;
  final String material;
  final double confidence;

  Map<String, dynamic> toJson() =>
      {'surface': surface, 'material': material, 'confidence': confidence};

  factory MaterialDetection.fromJson(Map<String, dynamic> j) => MaterialDetection(
        surface: j['surface'] as String? ?? '',
        material: j['material'] as String? ?? '',
        confidence: (j['confidence'] as num? ?? 0).toDouble(),
      );
}

class RoomModel {
  const RoomModel({
    required this.id,
    required this.projectId,
    required this.version,
    required this.roomType,
    required this.dimensionSource,
    required this.dimensions,
    this.floorPolygon = const [],
    this.openings = const [],
    this.furniture = const [],
    this.materials = const [],
    this.lightingObservation,
    this.assumptions = const [],
    this.photoPaths = const [],
  });

  final String id;
  final String projectId;
  final int version;
  final String roomType;
  final DimensionSource dimensionSource;
  final RoomDimensions dimensions;
  final List<math.Point<double>> floorPolygon;
  final List<Opening> openings;
  final List<FurnitureItem> furniture;
  final List<MaterialDetection> materials;
  final String? lightingObservation;
  final List<String> assumptions;
  final List<String> photoPaths;

  /// Shoelace polygon area when AR corners exist; rectangle fallback.
  double get floorAreaM2 {
    if (floorPolygon.length >= 3) {
      var sum = 0.0;
      for (var i = 0; i < floorPolygon.length; i++) {
        final a = floorPolygon[i];
        final b = floorPolygon[(i + 1) % floorPolygon.length];
        sum += a.x * b.y - b.x * a.y;
      }
      return sum.abs() / 2;
    }
    return dimensions.floorAreaM2;
  }

  double get wallAreaGrossM2 => dimensions.perimeterM * dimensions.heightM;

  double get wallAreaNetM2 => math.max(
      0, wallAreaGrossM2 - openings.fold(0.0, (s, o) => s + o.areaM2));

  double get ceilingAreaM2 => floorAreaM2;

  double get occupiedFloorM2 =>
      furniture.fold(0.0, (s, f) => s + f.footprintM2);

  double get freeFloorPct =>
      floorAreaM2 == 0 ? 0 : math.max(0, 1 - occupiedFloorM2 / floorAreaM2);

  Map<String, dynamic> toJson() => {
        'version': version,
        'roomType': roomType,
        'dimensionSource': dimensionSource.name,
        'dimensions': dimensions.toJson(),
        'floorPolygon':
            floorPolygon.map((p) => {'x': p.x, 'y': p.y}).toList(),
        'openings': openings.map((o) => o.toJson()).toList(),
        'furniture': furniture.map((f) => f.toJson()).toList(),
        'materials': materials.map((m) => m.toJson()).toList(),
        if (lightingObservation != null)
          'lightingObservation': lightingObservation,
        'assumptions': assumptions,
        'photoPaths': photoPaths,
      };

  factory RoomModel.fromJson(String id, String projectId, Map<String, dynamic> j) =>
      RoomModel(
        id: id,
        projectId: projectId,
        version: j['version'] as int? ?? 1,
        roomType: j['roomType'] as String? ?? 'other',
        dimensionSource: DimensionSource.values.firstWhere(
            (s) => s.name == j['dimensionSource'],
            orElse: () => DimensionSource.ai),
        dimensions: RoomDimensions.fromJson(
            (j['dimensions'] as Map<String, dynamic>?) ??
                {'lengthM': 0, 'widthM': 0, 'heightM': 2.4}),
        floorPolygon: (j['floorPolygon'] as List<dynamic>? ?? [])
            .map((p) => math.Point<double>(
                ((p as Map<String, dynamic>)['x'] as num).toDouble(),
                (p['y'] as num).toDouble()))
            .toList(),
        openings: (j['openings'] as List<dynamic>? ?? [])
            .map((o) => Opening.fromJson(o as Map<String, dynamic>))
            .toList(),
        furniture: (j['furniture'] as List<dynamic>? ?? [])
            .map((f) => FurnitureItem.fromJson(f as Map<String, dynamic>))
            .toList(),
        materials: (j['materials'] as List<dynamic>? ?? [])
            .map((m) => MaterialDetection.fromJson(m as Map<String, dynamic>))
            .toList(),
        lightingObservation: j['lightingObservation'] as String?,
        assumptions: (j['assumptions'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        photoPaths: (j['photoPaths'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}
