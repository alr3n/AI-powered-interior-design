# Implementation Guide — Setup, Testing, Deployment, Roadmap

## 1. Prerequisites
Flutter ≥ 3.24 stable, Dart ≥ 3.5, Supabase CLI (`npm i -g supabase`) with Docker
for local development, Android Studio +
SDK 34, a physical ARCore-certified Android device (AR won't run on emulators).

## 2. Supabase project setup
1. Create a project at supabase.com (or use the existing one).
2. **Authentication → Providers**: enable Email, **Anonymous sign-ins** (guest
   mode) and Google. In Google's provider settings paste your OAuth client
   ID/secret. **Authentication → Sign In / Providers → Allow manual linking**
   must be on so a guest can upgrade to Google without losing data.
3. **Authentication → URL Configuration → Redirect URLs**: add
   `io.supabase.spacesense://login-callback/` (mobile deep link).
4. Apply the schema: `supabase link --project-ref <ref>` then
   `supabase db push` (runs `supabase/migrations/*`). Then run
   `supabase/seed.sql` once in the dashboard's SQL editor to load the cost catalog
   and design tips.

## 3. App bootstrap
```bash
cd app
flutter pub get
flutter run                         # defaults point at the project in lib/core/config/env.dart
# or, per environment:
flutter run --dart-define-from-file=env.json   # copy env.example.json -> env.json
```
Android specifics (android/app/):
- `minSdk 24` (set in `build.gradle.kts`), `compileSdk` from Flutter
- Manifest already declares INTERNET, CAMERA and the OAuth deep link; ARCore
  optional: `<meta-data android:name="com.google.ar.core" android:value="optional" />`
- Google sign-in needs no SHA fingerprints in the app: the OAuth flow runs in the
  browser and returns through the deep link.

## 4. Edge Functions
```bash
supabase secrets set GEMINI_API_KEY=<fresh key>      # revoke any key that was ever exposed
supabase functions deploy extract-room analyze-room generate-design chat-assistant --no-verify-jwt
```
`--no-verify-jwt` matches `supabase/config.toml`: the functions verify the user's
token themselves (`_shared/http.ts`), which also works with asymmetric JWT keys.
Local: `supabase start` then `supabase functions serve --env-file supabase/.env.local`.

## 5. Run
`flutter run` on a real device. Guest mode works once Anonymous sign-ins are enabled in Supabase.

## 6. Build order (suggested sprints)
1. **S1 Foundation**: theme, router, auth, dashboard shell. ✅ scaffolded here
2. **S2 Scan**: capture flow, coverage tracking, upload, manual dims. ✅ scaffolded
3. **S3 AI core**: T1 extraction + T2 analysis end-to-end, analysis UI. ✅ scaffolded
4. **S4 AR measure**: ar_flutter_plugin_2 integration (device testing heavy).
5. **S5 Designs + chat + costs + quantities**. ✅ scaffolded
6. **S6 Reports (PDF), sustainability, settings polish.** ✅ scaffolded
7. **S7 Hardening**: attestation, rate limits, offline cache, error copy, a11y pass.

## 7. Testing strategy
- **Unit** (fast, most coverage): quantity calculators (golden numbers:
  4.2×3.5×2.7 room → wallNet, paint L), cost estimator tiers, walkway math,
  Failure mapping, prompt-input serializers. `flutter test`.
- **Provider tests**: Riverpod `ProviderContainer` with fake repos (override
  `authRepositoryProvider` etc.); assert AsyncValue transitions.
- **Widget**: login, capture checklist state, analysis screen renders scores
  from fixture JSON; goldens for ScoreRing/GlassCard both themes.
- **Edge Functions**: `deno test` with a mocked Gemini `fetch`; assert input
  validation, rate limiter (31st call in window → 429 resource-exhausted),
  cache hit path.
- **Integration** (`integration_test/`): auth→scan(mock camera)→analysis happy
  path against the local Supabase stack (`supabase start`).
- **RLS tests**: pgTAP (`supabase test db`) — cross-user read must return zero rows.
- **Manual AR test matrix**: 3+ ARCore devices, low light, small rooms.

## 8. Deployment
- **Android**: `flutter build appbundle --release`; Play Console internal
  testing → closed → production. Signing via `key.properties` (never committed).
- **iOS (later)**: same codebase; ARKit measure module swaps in behind the
  `DimensionSource` abstraction; TestFlight.
- **CI (GitHub Actions)**: on PR — `flutter analyze`, `flutter test`,
  `deno test` for functions; on tag — build appbundle, `supabase db push` +
  `supabase functions deploy` to the staging project; manual promote to prod.
  Two Supabase projects (staging / prod) selected via `supabase link`.
- **Monitoring**: Sentry/Crashlytics; Supabase function logs alerting
  on error-rate spikes; budget alert on Gemini spend.

## 9. Scalability roadmap
- **v1.1**: response streaming for chat; Remote Config for prompt versions and
  rate limits; localization (EN/PH-Tagalog).
- **v2**: AR furniture placement (GLB catalog), before/after image generation
  (Gemini image models) with slider compare, contractor share links (read-only
  project links), report white-labeling for designers.
- **v2.5**: 3D reconstruction (Depth API), room graph across whole home,
  multi-room projects, Google Maps project locations.
- **v3**: marketplace integrations (furniture affiliate feeds priced in PHP),
  team/workspace accounts for design firms, web viewer (Flutter web, read-only).
- **Cost control at scale**: cache hit-rate dashboards; Flash-first routing with
  Pro escalation only on user request; batch design generation.

## 10. Known risks
| Risk | Mitigation |
|---|---|
| AR plugin churn (ar_flutter_plugin forks) | isolate behind `ArMeasureService` interface; manual entry always available |
| Gemini output drift | responseSchema + server validation + prompt versioning in Remote Config |
| Photo quality variance | live luma check, retake prompts, confidence surfaced in UI |
| Cost data staleness | `cost_catalog` table, updatable without release |
