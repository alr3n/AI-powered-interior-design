# SpaceSense AI — Architecture

## 1. High-level system

```
┌─────────────────────────── Flutter App ───────────────────────────┐
│ Presentation (screens, widgets, Riverpod controllers)             │
│ Domain (entities, repository interfaces, use-case logic)          │
│ Data (Supabase repos, Edge-Function AI client, local cache)       │
└───────┬───────────────┬──────────────────┬────────────────────────┘
        │ Auth          │ Postgres/Storage │ Edge Functions
        ▼               ▼                  ▼
  Supabase Auth    Postgres (RLS) +     Edge Functions (Deno/TS)
                   Storage + Realtime     │  JWT check + rate limit
                                          ▼
                                     Gemini API
                              (2.5 Flash fast / 2.5 Pro reports)
```

**Key decision: Gemini is never called from the device.** The API key lives in
Supabase secrets; Edge Functions verify the caller's JWT, rate-limit per user
(Postgres `consume_ai_call`), cache responses in the `ai_cache` table, and
return structured JSON. This is the
only architecture that survives a production release — client-embedded keys are
extracted within hours of publishing an APK.

## 2. Clean Architecture layers (per feature)

```
features/<feature>/
  domain/        entities + abstract repositories (pure Dart, no Flutter/Supabase imports)
  data/          repository implementations (Supabase, Edge Functions, camera, ARCore)
  presentation/  screens, widgets, Riverpod providers/controllers
```

Dependency rule: presentation → domain ← data. Data implements domain
interfaces; providers wire them (`authRepositoryProvider` returns
`SupabaseAuthRepository` as `AuthRepository`). Swapping the backend touches
only `data/` (the app moved from Firebase to Supabase this way).

Why Riverpod over Bloc: compile-safe DI + reactive state in one tool; providers
compose (analysis controller watches room provider watches auth provider) without
context plumbing. `AsyncNotifier` gives loading/error/data states for free.

Why GoRouter: declarative deep-linkable routes, redirect guard for auth,
ShellRoute for the bottom-nav shell.

## 3. Folder structure (app/lib)

```
lib/
  main.dart                     bootstrap: Supabase init, ProviderScope
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
  services/       GeminiClient (Edge Function wrapper), StorageService, CacheService
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
3. **Gemini vision pass** (Edge Function): images + measured dims → structured
   JSON: room type, dimension estimates (reconciled with AR data), furniture
   inventory with approximate sizes, materials with confidence, openings, lighting.
4. **RoomModel** persisted to Postgres (`rooms`); photos to Supabase Storage.

Full 3D mesh reconstruction is deliberately v2 (see 05 doc): on-device
photogrammetry is the highest-risk item and the AI analysis value chain doesn't
depend on it.

## 5. AI model routing

| Task | Model | Why |
|---|---|---|
| Vision extraction, chat, quick tips | gemini-2.5-flash | latency + cost |
| Full interior analysis report, design concepts | gemini-2.5-pro | reasoning depth |
| All calls | responseSchema JSON mode | deterministic parsing |

Responses cached in `ai_cache` (key = hash of prompt version + task + payload); a room re-analysis is
only billed when the room model changed.

## 6. Error handling

- Sealed `Failure` types (`NetworkFailure`, `AiFailure`, `AuthFailure`,
  `ValidationFailure`, `QuotaFailure`) mapped at the data layer; presentation
  never sees raw exceptions.
- Every AsyncNotifier exposes `AsyncValue`; `AsyncValueView` widget renders
  loading/skeleton, error with retry, and data uniformly.
- Edge Functions return `{ error: { code, message } }` with an HTTP status
  (429 `resource-exhausted` for the rate limit, 400 `failed-precondition` for
  missing scan data) that the client maps to friendly copy.

## 7. Performance

- Image compression before upload (flutter_image_compress), thumbnails via
  Storage image transformations.
- AI response caching (Postgres `ai_cache`).
- Lazy route loading; `ListView.builder` everywhere; `cached_network_image`.
- Heavy JSON parsing via `compute()` isolates.

## 8. Security

- Gemini key: Supabase secret only (`supabase secrets set GEMINI_API_KEY=…`).
- Row Level Security on every table: strict per-owner access (see
  `supabase/migrations`). `ai_cache` / `ai_usage` have no policies at all, so
  only the service role can touch them.
- Storage policies: bucket `scan-photos`, path-scoped `<uid>/…`, image MIME types
  + 10 MB limit.
- Only the publishable key ships in the app; the service-role key exists only
  inside Edge Functions.
- Rate limit: 30 AI calls/user/hour (atomic Postgres function).
- Local sensitive prefs via flutter_secure_storage.

## 9. SOLID in practice

- S: each repo does one aggregate (RoomRepository ≠ AnalysisRepository).
- O: `DesignStyle` catalog is data-driven; adding a style = adding an entry.
- L: fake repos substitute real ones in tests via provider overrides.
- I: narrow repo interfaces per consumer.
- D: presentation depends on abstract repos, injected by Riverpod.
