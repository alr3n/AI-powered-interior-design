# Implementation Guide — Setup, Testing, Deployment, Roadmap

## 1. Prerequisites
Flutter ≥ 3.24 stable, Dart ≥ 3.5, Node 20, Firebase CLI (`npm i -g firebase-tools`),
FlutterFire CLI (`dart pub global activate flutterfire_cli`), Android Studio +
SDK 34, a physical ARCore-certified Android device (AR won't run on emulators).

## 2. Firebase project setup
1. Create project at console.firebase.google.com; enable **Authentication**
   (Google, Email/Password, Anonymous), **Firestore** (production mode),
   **Storage**, **App Check** (Play Integrity).
2. `firebase login && firebase init` in repo root → select Firestore, Storage,
   Functions; point rules at `firebase/firestore.rules`, `firebase/storage.rules`,
   indexes at `firebase/firestore.indexes.json`.
3. Seed `costCatalog/PH` and a few `designTips` docs (shapes in doc 02).

## 3. App bootstrap
```bash
cd app
flutter create . --org com.spacesense --platforms android,ios   # generates android/ ios/
flutterfire configure                                            # writes firebase_options.dart
flutter pub get
```
Android specifics (android/app/):
- `minSdkVersion 24`, `compileSdkVersion 34`
- Manifest: CAMERA permission; ARCore optional:
  `<meta-data android:name="com.google.ar.core" android:value="optional" />`
- Google Sign-In: add SHA-1/SHA-256 fingerprints in Firebase console.

## 4. Functions
```bash
cd functions && npm i
firebase functions:secrets:set GEMINI_API_KEY     # paste a FRESH key (revoke any exposed one)
npm run build && firebase deploy --only functions
```

## 5. Run
`flutter run` on a real device. Guest mode works with zero config beyond Firebase.

## 6. Build order (suggested sprints)
1. **S1 Foundation**: theme, router, auth, dashboard shell. ✅ scaffolded here
2. **S2 Scan**: capture flow, coverage tracking, upload, manual dims. ✅ scaffolded
3. **S3 AI core**: T1 extraction + T2 analysis end-to-end, analysis UI. ✅ scaffolded
4. **S4 AR measure**: ar_flutter_plugin_2 integration (device testing heavy).
5. **S5 Designs + chat + costs + quantities**. ✅ scaffolded
6. **S6 Reports (PDF), sustainability, settings polish.** ✅ scaffolded
7. **S7 Hardening**: App Check, rate limits, offline cache, error copy, a11y pass.

## 7. Testing strategy
- **Unit** (fast, most coverage): quantity calculators (golden numbers:
  4.2×3.5×2.7 room → wallNet, paint L), cost estimator tiers, walkway math,
  Failure mapping, prompt-input serializers. `flutter test`.
- **Provider tests**: Riverpod `ProviderContainer` with fake repos (override
  `authRepositoryProvider` etc.); assert AsyncValue transitions.
- **Widget**: login, capture checklist state, analysis screen renders scores
  from fixture JSON; goldens for ScoreRing/GlassCard both themes.
- **Functions**: vitest + firebase-functions-test; mock Gemini client; assert
  schema validation, rate limiter (31st call in window → resource-exhausted),
  cache hit path.
- **Integration** (`integration_test/`): auth→scan(mock camera)→analysis happy
  path against Firebase **emulator suite** (`firebase emulators:start`).
- **Rules tests**: @firebase/rules-unit-testing — cross-user read must fail.
- **Manual AR test matrix**: 3+ ARCore devices, low light, small rooms.

## 8. Deployment
- **Android**: `flutter build appbundle --release`; Play Console internal
  testing → closed → production. Signing via `key.properties` (never committed).
  Play Integrity registered for App Check.
- **iOS (later)**: same codebase; ARKit measure module swaps in behind the
  `DimensionSource` abstraction; TestFlight.
- **CI (GitHub Actions)**: on PR — `flutter analyze`, `flutter test`,
  `npm test` in functions; on tag — build appbundle, deploy functions + rules
  to staging project; manual promote to prod. Two Firebase projects
  (spacesense-staging / spacesense-prod) selected via `firebase use`.
- **Monitoring**: Crashlytics + Performance Monitoring; function logs alerting
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
| Cost data staleness | costCatalog in Firestore, updatable without release |
