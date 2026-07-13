# SpaceSense AI — Architecture

## 1. High-level system

```
┌─────────────────────────── Flutter App ───────────────────────────┐
│ Presentation (screens, widgets, Riverpod controllers)             │
│ Domain (entities, repository interfaces, use-case logic)          │
│ Data (Firebase repos, callable-function AI client, local cache)   │
└───────┬───────────────┬──────────────────┬────────────────────────┘
        │ Auth          │ Firestore/Storage│ Callable Functions
        ▼               ▼                  ▼
  Firebase Auth    Firestore + Storage   Cloud Functions (TS)
                                          │  App Check + rate limit
                                          ▼
                                     Gemini API
                              (2.5 Flash fast / 2.5 Pro reports)
```

**Key decision: Gemini is never called from the device.** The API key lives in
Secret Manager; callable functions validate auth, enforce App Check, rate-limit
per user, cache responses in Firestore, and return structured JSON. This is the
only architecture that survives a production release — client-embedded keys are
extracted within hours of publishing an APK.

## 2. Clean Architecture layers (per feature)

```
features/<feature>/
  domain/        entities + abstract repositories (pure Dart, no Flutter/Firebase imports)
  data/          repository implementations (Firestore, Functions, camera, ARCore)
  presentation/  screens, widgets, Riverpod providers/controllers
```

Dependency rule: presentation → domain ← data. Data implements domain
interfaces; providers wire them (`authRepositoryProvider` returns
`FirebaseAuthRepository` as `AuthRepository`). Swapping Firebase for Supabase
later touches only `data/`.

Why Riverpod over Bloc: compile-safe DI + reactive state in one tool; providers
compose (analysis controller watches room provider watches auth provider) without
context plumbing. `AsyncNotifier` gives loading/error/data states for free.

Why GoRouter: declarative deep-linkable routes, redirect guard for auth,
ShellRoute for the bottom-nav shell.

## 3. Folder structure (app/lib)

```
lib/
  main.dart                     bootstrap: Firebase init, ProviderScope
  app.dart                      MaterialApp.router, themes
  core/
    constants/app_constants.dart
    errors/failures.dart        sealed Failure hierarchy
    router/app_router.dart
    theme/app_theme.dart        M3 light/dark, typography, glass surfaces
    widgets/                    GlassCard, ScoreRing, AsyncValueView, SectionHeader
  features/
    auth/         {domain,data,presentation}
    dashboard/    home dashboard, tips, stats
    projects/     project list, room model CRUD
    scan/         guided capture, coverage checklist, AR measure
    analysis/     Gemini interior analysis, scores
    designs/      style generator (12 styles)
    chat/         context-aware assistant
    cost/         estimator, budget tiers
    quantities/   paint/tile/flooring take-offs
    sustainability/
    reports/      PDF generation
    settings/     theme mode, currency, region multiplier
  models/         shared cross-feature entities (RoomModel, FurnitureItem, ...)
  services/       GeminiClient (callable wrapper), StorageService, CacheService
```

Shared `models/` + `services/` sit beside features because Room entities are used
by 8+ features; duplicating them per-feature would violate DRY worse than the
slight layering compromise.

## 4. Scan pipeline (hybrid, v1)

1. **Guided capture** — camera flow with a coverage checklist (4 walls, floor,
   ceiling, windows, doors, furniture). Each shot is tagged with its target and
   device orientation. Images compressed (~1280px, q80) before upload.
2. **AR measure** — ARCore plane detection (ar_flutter_plugin_2) lets the user tap
   floor corners; we compute wall lengths + floor polygon; ceiling height from a
   floor-to-ceiling two-tap measure. These *measured* dimensions override AI
   estimates.
3. **Gemini vision pass** (Cloud Function): images + measured dims → structured
   JSON: room type, dimension estimates (reconciled with AR data), furniture
   inventory with approximate sizes, materials with confidence, openings, lighting.
4. **RoomModel** persisted to Firestore + local cache; photos to Storage.

Full 3D mesh reconstruction is deliberately v2 (see 05 doc): on-device
photogrammetry is the highest-risk item and the AI analysis value chain doesn't
depend on it.

## 5. AI model routing

| Task | Model | Why |
|---|---|---|
| Vision extraction, chat, quick tips | gemini-2.5-flash | latency + cost |
| Full interior analysis report, design concepts | gemini-2.5-pro | reasoning depth |
| All calls | responseSchema JSON mode | deterministic parsing |

Responses cached in `aiCache/{hash(roomVersion+task)}`; a room re-analysis is
only billed when the room model changed.

## 6. Error handling

- Sealed `Failure` types (`NetworkFailure`, `AiFailure`, `AuthFailure`,
  `ValidationFailure`, `QuotaFailure`) mapped at the data layer; presentation
  never sees raw exceptions.
- Every AsyncNotifier exposes `AsyncValue`; `AsyncValueView` widget renders
  loading/skeleton, error with retry, and data uniformly.
- Cloud Functions return typed error codes (`resource-exhausted` for rate limit,
  `failed-precondition` for missing scan data) that the client maps to friendly
  copy.

## 7. Performance

- Image compression before upload (flutter_image_compress), thumbnails via
  Storage resize extension.
- AI response caching (Firestore + in-memory).
- Lazy route loading; `ListView.builder` everywhere; `cached_network_image`.
- Heavy JSON parsing via `compute()` isolates.

## 8. Security

- Gemini key: Secret Manager only.
- Firestore rules: strict per-owner access (see firebase/firestore.rules).
- Storage rules: path-scoped `users/{uid}/**`, content-type + 10 MB validation.
- App Check (Play Integrity) on callable functions.
- Rate limit: 30 AI calls/user/hour (Firestore counter, transactional).
- Local sensitive prefs via flutter_secure_storage.

## 9. SOLID in practice

- S: each repo does one aggregate (RoomRepository ≠ AnalysisRepository).
- O: `DesignStyle` catalog is data-driven; adding a style = adding an entry.
- L: fake repos substitute real ones in tests via provider overrides.
- I: narrow repo interfaces per consumer.
- D: presentation depends on abstract repos, injected by Riverpod.
