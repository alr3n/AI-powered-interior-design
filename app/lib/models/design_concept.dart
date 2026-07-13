class PaletteColor {
  const PaletteColor({required this.hex, required this.role});
  final String hex;
  final String role;

  factory PaletteColor.fromJson(Map<String, dynamic> j) => PaletteColor(
      hex: j['hex'] as String? ?? '#CCCCCC', role: j['role'] as String? ?? '');
  Map<String, dynamic> toJson() => {'hex': hex, 'role': role};
}

class DesignFurniture {
  const DesignFurniture(
      {required this.item, this.estPrice, required this.priority});
  final String item;
  final double? estPrice;
  final String priority; // core | optional

  factory DesignFurniture.fromJson(Map<String, dynamic> j) => DesignFurniture(
        item: j['item'] as String? ?? '',
        estPrice: (j['estPrice'] as num?)?.toDouble(),
        priority: j['priority'] as String? ?? 'optional',
      );
  Map<String, dynamic> toJson() =>
      {'item': item, if (estPrice != null) 'estPrice': estPrice, 'priority': priority};
}

class DesignConcept {
  const DesignConcept({
    required this.style,
    required this.mood,
    required this.palette,
    required this.materials,
    required this.flooring,
    required this.wallFinish,
    required this.furniture,
    required this.lighting,
    required this.decor,
    required this.budgetTotal,
    required this.difficulty,
    required this.maintenance,
  });

  final String style;
  final String mood;
  final List<PaletteColor> palette;
  final List<String> materials;
  final String flooring;
  final String wallFinish;
  final List<DesignFurniture> furniture;
  final List<String> lighting;
  final List<String> decor;
  final double budgetTotal;
  final String difficulty;
  final String maintenance;

  factory DesignConcept.fromJson(Map<String, dynamic> j) => DesignConcept(
        style: j['style'] as String? ?? '',
        mood: j['mood'] as String? ?? '',
        palette: (j['palette'] as List<dynamic>? ?? [])
            .map((p) => PaletteColor.fromJson(p as Map<String, dynamic>))
            .toList(),
        materials: _strings(j['materials']),
        flooring: j['flooring'] as String? ?? '',
        wallFinish: j['wallFinish'] as String? ?? '',
        furniture: (j['furniture'] as List<dynamic>? ?? [])
            .map((f) => DesignFurniture.fromJson(f as Map<String, dynamic>))
            .toList(),
        lighting: _strings(j['lighting']),
        decor: _strings(j['decor']),
        budgetTotal: (j['budgetTotal'] as num? ?? 0).toDouble(),
        difficulty: j['difficulty'] as String? ?? 'moderate',
        maintenance: j['maintenance'] as String? ?? 'medium',
      );

  Map<String, dynamic> toJson() => {
        'style': style, 'mood': mood,
        'palette': palette.map((p) => p.toJson()).toList(),
        'materials': materials, 'flooring': flooring, 'wallFinish': wallFinish,
        'furniture': furniture.map((f) => f.toJson()).toList(),
        'lighting': lighting, 'decor': decor, 'budgetTotal': budgetTotal,
        'difficulty': difficulty, 'maintenance': maintenance,
      };

  static List<String> _strings(dynamic v) =>
      (v as List<dynamic>? ?? []).map((e) => e.toString()).toList();
}
