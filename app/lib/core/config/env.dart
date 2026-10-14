/// Build-time configuration. Override per environment with
/// `flutter run --dart-define-from-file=env.json` (see env.example.json).
///
/// The publishable key is designed to ship inside client apps — access is
/// enforced by Row Level Security. NEVER put a secret / service-role key here.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gibshfcsjtztczlksdhs.supabase.co',
  );

  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_tSn1W_pEPjNpg68GeovGkQ_sVSWTuUO',
  );

  /// Deep link that returns the OAuth (Google) flow to the app on
  /// Android / iOS. Must match AndroidManifest.xml, Info.plist and the
  /// "Redirect URLs" list in the Supabase dashboard.
  static const authRedirect = 'io.supabase.spacesense://login-callback/';
}
