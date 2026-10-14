# SpaceSense AI

AI-powered interior scanning, analysis, and redesign platform, built with Flutter, Supabase, and Google Gemini.

SpaceSense AI turns a guided phone scan of a room into a structured room model, a
professional 13-category interior analysis, AI-generated redesign concepts,
civil-engineering quantity take-offs, and a cost estimate — all backed by Google
Gemini through server-side Supabase Edge Functions, so no AI credentials ever
ship inside the app.

## Table of contents

- [Features](#features)
- [Tech stack](#tech-stack)
- [Repository layout](#repository-layout)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [Development](#development)
- [Deployment](#deployment)
- [Security](#security)
- [Documentation](#documentation)
- [Roadmap](#roadmap)
- [License](#license)

## Features

- **Authentication** — Google, email/password, and anonymous guest
  accounts (Supabase Auth), with guest upgrade that preserves existing data.
- **Guided room scan** — a 10-step coverage checklist (walls, floor, ceiling,
  windows, doors, wide shots) plus manual or AI-estimated dimensions.
- **AI room extraction** — Gemini turns captured photos into a structured room
  model: dimensions, furniture, materials, openings, and lighting notes.
- **Interior analysis** — a 13-category score (functionality, ergonomics,
  traffic flow, lighting, storage, safety, and more) with cited strengths,
  weaknesses, and actionable, costed recommendations.
- **Design concepts** — redesign proposals across 12 styles (Minimalist,
  Scandinavian, Japandi, Industrial, and others), each with a palette,
  materials, furniture list, and budget.
- **Quantity take-offs** — paint, tile, and flooring quantities with waste
  factors, skirting length, and a guidance-level walkway clearance check.
  Planning estimates only — not a substitute for a professional take-off or
  building-code review.
- **Cost estimation** — four budget tiers (low/medium/premium/luxury) against
  a regional rate card, defaulting to the Philippine market (PHP).
- **AI chat assistant** — a context-aware assistant that answers questions
  using the current room's real numbers.
- **PDF reports** — a shareable report combining the room summary, analysis,
  quantities, cost breakdown, and design concepts, generated on-device.
- **Server-side AI governance** — per-user hourly rate limiting and response
  caching live in Edge Functions + Postgres, not the client.

## Tech stack

| Layer             | Technology                                                         |
|-------------------|--------------------------------------------------------------------|
| Client            | Flutter 3.x / Dart 3.5+, Riverpod, go_router                       |
| Backend           | Supabase: Auth, Postgres (RLS + Realtime), Storage, Edge Functions |
| AI                | Google Gemini (`gemini-2.5-flash`, `gemini-2.5-pro`) via REST      |
| Functions runtime | Deno (Supabase Edge Functions), TypeScript                         |
| Reports           | `pdf` / `printing` (client-side PDF generation)                    |

## Repository layout

```
docs/          Architecture, database schema, AI prompt strategy, CV/AR
               workflow, and implementation guide
app/           Flutter application
supabase/      Backend: SQL migrations (schema, RLS, storage, realtime),
               seed data, and the Edge Functions — the only place Gemini
               is called
```

## Getting started

### Prerequisites

- [Flutter SDK](https://flutter.dev) 3.5+ and Dart 3.5+
- A [Supabase](https://supabase.com) project and the
  [Supabase CLI](https://supabase.com/docs/guides/cli) (`npm i -g supabase`)
- A [Google Gemini API key](https://ai.google.dev/)

### 1. Clone

```bash
git clone https://github.com/alr3n/AI-powered-interior-design.git
cd AI-powered-interior-design
```

### 2. Set up Supabase

In the dashboard:

- **Authentication → Providers**: enable Email, **Anonymous sign-ins**, and
  Google; turn on **Allow manual linking** (guest → Google upgrade).
- **Authentication → URL Configuration**: add the redirect URL
  `io.supabase.spacesense://login-callback/`.

Then from the repo root:

```bash
supabase link --project-ref <your-project-ref>
supabase db push                                   # tables, RLS, storage, realtime
# run supabase/seed.sql once in the SQL editor (cost catalog + design tips)
supabase secrets set GEMINI_API_KEY=<your key>
supabase functions deploy extract-room analyze-room generate-design chat-assistant --no-verify-jwt
```

### 3. Run the app

```bash
cd app
flutter pub get
flutter run
```

The Supabase URL and **publishable** key default to this project's values in
`app/lib/core/config/env.dart`; override them per environment with
`flutter run --dart-define-from-file=env.json` (see `app/env.example.json`).

See [`docs/05-IMPLEMENTATION_GUIDE.md`](docs/05-IMPLEMENTATION_GUIDE.md) for the
full walkthrough, including platform-specific setup.

## Configuration

| Setting                        | Where                                             |
|--------------------------------|---------------------------------------------------|
| `GEMINI_API_KEY`               | Supabase secret (`supabase secrets set`)          |
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` | `--dart-define` / defaults in `app/lib/core/config/env.dart` |
| Regional cost rate cards       | Postgres `cost_catalog` table (seeded for `PH`)   |
| Default budget tier / currency | `app/lib/core/constants/app_constants.dart`       |

> The `NEXT_PUBLIC_SUPABASE_*` names are the Next.js convention; Flutter reads
> `SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY` instead.

## Development

```bash
# Flutter: static analysis and unit tests
cd app
flutter analyze
flutter test

# Backend: local stack + functions
supabase start
supabase functions serve --env-file supabase/.env.local   # GEMINI_API_KEY=...
```

## Deployment

```bash
supabase db push
supabase functions deploy extract-room analyze-room generate-design chat-assistant --no-verify-jwt
```

## Security

- The Gemini API key is stored as a Supabase secret and never ships inside the
  app; all AI calls go through Edge Functions that verify the caller's JWT.
- Only the **publishable** key is in the app. Never commit a secret /
  service-role key; Row Level Security is what protects the data.
- Every table has RLS: projects are scoped to `owner_id`, their rooms /
  analyses / designs to the owning project, and photos to `<uid>/…` paths in a
  private bucket. `ai_cache` and `ai_usage` are reachable only by the service
  role.
- AI usage is rate-limited per user (atomic Postgres function, 30 calls/hour)
  and cached by prompt version to control cost and abuse. Design style and
  budget tier are checked against allow-lists before reaching a prompt.
- If a Gemini key is ever pasted into a chat, doc, or commit, revoke it and
  issue a new one.

## Documentation

- [`docs/01-ARCHITECTURE.md`](docs/01-ARCHITECTURE.md)
- [`docs/02-DATABASE_SCHEMA.md`](docs/02-DATABASE_SCHEMA.md)
- [`docs/03-AI_PROMPT_STRATEGY.md`](docs/03-AI_PROMPT_STRATEGY.md)
- [`docs/04-CV_AR_WORKFLOW.md`](docs/04-CV_AR_WORKFLOW.md)
- [`docs/05-IMPLEMENTATION_GUIDE.md`](docs/05-IMPLEMENTATION_GUIDE.md)

## Roadmap

v1 (this codebase) covers scanning, analysis, design generation, quantities,
cost estimation, chat, and PDF export. Planned for v2:

- AR-assisted tap-to-measure dimensions (replacing manual entry)
- AR furniture placement
- Before/after image generation
- 3D room reconstruction

Details are tracked in [`docs/05-IMPLEMENTATION_GUIDE.md`](docs/05-IMPLEMENTATION_GUIDE.md).

## License

No license has been published for this repository yet; all rights are
reserved by the author unless a `LICENSE` file states otherwise.
