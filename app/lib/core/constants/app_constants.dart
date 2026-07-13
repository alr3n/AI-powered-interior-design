class AppConstants {
  AppConstants._();

  static const appName = 'SpaceSense AI';
  static const defaultRegion = 'PH';
  static const defaultCurrency = 'PHP';
  static const currencySymbol = '₱';

  // Quantity take-off constants (see docs/04, all estimates only)
  static const paintCoverageM2PerLiter = 10.0;
  static const paintCoats = 2;
  static const paintWasteFactor = 1.10;
  static const tileWasteFactor = 1.10;
  static const tileWasteFactorDiagonal = 1.15;
  static const flooringWasteFactor = 1.08;
  static const minWalkwayM = 0.75;

  // Capture
  static const maxImageDimension = 1280;
  static const jpegQuality = 80;
  static const maxScanShots = 12;

  static const budgetTiers = ['low', 'medium', 'premium', 'luxury'];

  static const designStyles = [
    'Minimalist', 'Modern', 'Industrial', 'Scandinavian', 'Japandi', 'Luxury',
    'Classic', 'Bohemian', 'Farmhouse', 'Contemporary', 'Tropical', 'Coastal',
  ];

  static const roomTypes = [
    'bedroom', 'living room', 'kitchen', 'dining room', 'bathroom',
    'home office', 'studio', 'other',
  ];
}
