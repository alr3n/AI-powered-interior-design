/// Coverage-driven scan flow. Each target must be captured before the scan
/// can be submitted for AI extraction.
enum ScanTarget {
  wallNorth('Wall 1', 'Stand back and fit the whole wall in frame'),
  wallEast('Wall 2', 'Turn right — capture the next wall'),
  wallSouth('Wall 3', 'Keep turning — third wall'),
  wallWest('Wall 4', 'Last wall — include corners if you can'),
  floor('Floor', 'Angle down 45°, include furniture feet'),
  ceiling('Ceiling', 'Include at least one wall edge for scale'),
  windows('Windows', 'Fill about 60% of the frame'),
  doors('Doors', 'Capture the full door and frame'),
  furnitureA('Room view 1', 'Wide shot from one corner'),
  furnitureB('Room view 2', 'Wide shot from the opposite corner');

  const ScanTarget(this.label, this.instruction);
  final String label;
  final String instruction;
}

class CapturedShot {
  const CapturedShot({required this.target, required this.filePath});
  final ScanTarget target;
  final String filePath;
}

class ScanSession {
  const ScanSession({
    this.shots = const [],
    this.currentIndex = 0,
    this.manualDimensions,
  });

  final List<CapturedShot> shots;
  final int currentIndex;

  /// {lengthM, widthM, heightM} — from AR measure or manual entry.
  final Map<String, double>? manualDimensions;

  ScanTarget get currentTarget => ScanTarget.values[currentIndex];
  bool get isComplete => currentIndex >= ScanTarget.values.length;
  double get progress => shots.length / ScanTarget.values.length;

  bool captured(ScanTarget t) => shots.any((s) => s.target == t);

  ScanSession copyWith({
    List<CapturedShot>? shots,
    int? currentIndex,
    Map<String, double>? manualDimensions,
  }) =>
      ScanSession(
        shots: shots ?? this.shots,
        currentIndex: currentIndex ?? this.currentIndex,
        manualDimensions: manualDimensions ?? this.manualDimensions,
      );
}
