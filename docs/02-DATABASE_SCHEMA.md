# Database Schema (Supabase / Postgres)

The schema lives in [`supabase/migrations/20261014000000_init.sql`](../supabase/migrations/20261014000000_init.sql)
(reference data in [`supabase/seed.sql`](../supabase/seed.sql)). Every table has
Row Level Security enabled. The former Firestore sub-collections are now
relational tables; the document bodies (`rooms.data`, `analyses.data`,
`designs.data`) keep their original JSON shape in `jsonb` columns, so the Dart
models (`toJson` / `fromJson`) are unchanged.

## Tables

### `profiles` — one row per auth user
Created and kept in sync by triggers on `auth.users` (sign-up, guest → permanent
upgrade, OAuth metadata). Users can read and update only their own row.

| column | type | notes |
|---|---|---|
| `id` | uuid PK → `auth.users` | cascade delete |
| `display_name`, `email`, `photo_url` | text | from auth metadata |
| `is_guest` | boolean | mirrors `auth.users.is_anonymous` |
| `region`, `currency` | text | default `PH` / `PHP` |
| `preferences` | jsonb | `themeMode`, `budgetTier`, `occupants`, `hasChildren`, `hasPets`, `accessibilityNeeds` |
| `created_at`, `updated_at` | timestamptz | |

### `projects`
| column | type | notes |
|---|---|---|
| `id` | uuid PK | |
| `owner_id` | uuid → `auth.users` | defaults to `auth.uid()` |
| `name` | text | 1–120 chars |
| `room_type` | text | |
| `status` | text | `scanned \| analyzed \| designed \| archived` |
| `cover_photo_url` | text? | |
| `is_favorite` | boolean | toggling does not change `updated_at` |
| `created_at`, `updated_at` | timestamptz | index `(owner_id, updated_at desc)` |

### `rooms` — reconstructed room model, versioned
`unique (project_id, version)`; `data` is `RoomModel.toJson()`:

```json
{
  "version": 1, "roomType": "bedroom", "dimensionSource": "ar | ai | manual",
  "dimensions": { "lengthM": 4.2, "widthM": 3.5, "heightM": 2.7 },
  "floorPolygon": [{ "x": 0, "y": 0 }],
  "openings": [{ "type": "door|window", "widthM": 0.9, "heightM": 2.1 }],
  "furniture": [{ "category": "bed", "label": "Queen bed",
                  "lengthM": 2.0, "widthM": 1.5, "heightM": 0.5, "confidence": 0.9 }],
  "materials": [{ "surface": "floor", "material": "tiles", "confidence": 0.85 }],
  "lightingObservation": "string?", "assumptions": ["…"],
  "photoPaths": ["<uid>/<projectId>/scan/wallNorth.jpg"]
}
```
`photoPaths` are object paths in the private `scan-photos` Storage bucket.

### `analyses` — Gemini output, stored verbatim
`project_id`, `room_version`, `data` (`AnalysisResult.toJson()`), `created_at`.
```json
{ "overallScore": 88,
  "categoryScores": { "functionality": 85, "ergonomics": 80, "trafficFlow": 78,
    "lighting": 90, "furnitureArrangement": 82, "spaceUtilization": 75,
    "storage": 70, "visualBalance": 88, "colorHarmony": 91,
    "accessibility": 72, "sustainability": 68, "comfort": 86, "safety": 89 },
  "strengths": ["…"], "weaknesses": ["…"],
  "recommendations": [{ "title": "…", "detail": "…", "priority": "high|medium|low", "estCost": 4500 }],
  "assumptions": ["…"] }
```

### `designs` — one generated style concept per row
`project_id`, `data` (`DesignConcept.toJson()`), `created_at`.
```json
{ "style": "Japandi", "mood": "…",
  "palette": [{ "hex": "#E8E2D5", "role": "walls" }],
  "materials": ["white oak", "linen"], "flooring": "engineered oak",
  "wallFinish": "limewash paint",
  "furniture": [{ "item": "low platform bed", "estPrice": 25000, "priority": "core" }],
  "lighting": ["paper pendant"], "decor": ["…"],
  "budgetTotal": 120000, "difficulty": "moderate", "maintenance": "low" }
```

### Reference data (public read, written by migrations/admins only)
- `design_tips (id, text, category, active_date)`
- `cost_catalog (region PK, currency, rates jsonb)` — PHP unit rates by budget tier:
  `{ "paint_liter": {"low":400,"medium":650,"premium":950,"luxury":1500}, … }`

### Server-only (RLS on, **no policies** → service role only)
- `ai_cache (key PK, task, response jsonb, model, created_at, expires_at)`
- `ai_usage (user_id PK, window_start, calls)` — advanced only through
  `consume_ai_call(user, limit)`, an atomic fixed-window limiter (30 / hour).

## Storage
Private bucket `scan-photos` (10 MB limit; jpeg / png / webp):
```
<uid>/<projectId>/scan/<target>.jpg
```
Storage policies allow a user to read / write / delete only objects whose first
path segment is their own uid.

## Access model
- `projects`: `owner_id = auth.uid()` for select / insert / update / delete.
- `rooms`, `analyses`, `designs`: allowed when the parent project is owned by
  the caller (`exists` check against `projects`).
- Guests use Supabase **anonymous sign-ins** and get full functionality. Upgrading
  to Google (`linkIdentity`) or email/password (`updateUser`) keeps the same
  `auth.uid()`, so no data is copied.
- Realtime is enabled on `projects`, `rooms`, `analyses`, `designs`; the app uses
  `.stream()` on them where it used Firestore snapshots.
