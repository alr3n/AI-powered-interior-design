# SpaceSense AI

AI-powered interior scanning, analysis, and redesign platform, built with Flutter, Firebase, and Google Gemini.

SpaceSense AI turns a guided phone scan of a room into a structured room model, a
professional 13-category interior analysis, AI-generated redesign concepts,
civil-engineering quantity take-offs, and a cost estimate — all backed by Google
Gemini through server-side Cloud Functions, so no AI credentials ever ship inside
the app.

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

- **Authentication** — Google Sign-In, email/password, and anonymous guest
  accounts, with guest-to-Google account upgrade that preserves existing data.
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
  caching live in Cloud Functions, not the client.

## Tech stack

| Layer            | Technology                                                        |
|-------------------|--------------------------------------------------------------------|
| Client            | Flutter 3.x / Dart 3.5+, Riverpod, go_router                       |
| Backend           | Firebase Auth, Firestore, Storage, Cloud Functions (2nd gen)       |
| AI                | Google Gemini (`gemini-2.5-flash`, `gemini-2.5-pro`) via `@google/genai` |
| Functions runtime | Node.js 20, TypeScript                                             |
| Reports           | `pdf` / `printing` (client-side PDF generation)                   |

## Repository layout

```
docs/          Architecture, database schema, AI prompt strategy, CV/AR
               workflow, and implementation guide
app/           Flutter application
functions/     Firebase Cloud Functions (TypeScript) — the only place
               Gemini is called
firebase/      Firestore/Storage security rules and indexes
firebase.json  Firebase project configuration
```

## Getting started

### Prerequisites

- [Flutter SDK](https://flutter.dev) 3.5+ and Dart 3.5+
- [Node.js](https://nodejs.org) 20
- A [Firebase](https://firebase.google.com) project (Blaze plan, required for
  Cloud Functions outbound network calls to Gemini)
- The [Firebase CLI](https://firebase.google.com/docs/cli) and
  [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) (`dart pub
  global activate flutterfire_cli`)
- A [Google Gemini API key](https://ai.google.dev/)

### 1. Clone and install

```bash
git clone https://github.com/alr3n/AI-powered-interior-design.git
cd AI-powered-interior-design
```

### 2. Set up the Firebase project

Create a Firebase project in the console and enable:

- **Authentication** — Google, Email/Password, and Anonymous sign-in
- **Firestore** and **Storage**

### 3. Configure the Flutter app

```bash
cd app
flutter pub get
flutterfire configure   # generates lib/firebase_options.dart with your project's config
```

### 4. Deploy Cloud Functions

```bash
cd functions
npm install
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

### 5. Run the app

```bash
cd app
flutter run
```

See [`docs/05-IMPLEMENTATION_GUIDE.md`](docs/05-IMPLEMENTATION_GUIDE.md) for the
full walkthrough, including platform-specific setup (Android/iOS signing,
Google Sign-In OAuth clients, etc.).

## Configuration

| Setting                        | Where                                             |
|----------------------------------|----------------------------------------------------|
| `GEMINI_API_KEY`                | Firebase Functions secret (`firebase functions:secrets:set`) |
| Firebase client config          | `app/lib/firebase_options.dart` (generated by `flutterfire configure`, never committed as a placeholder) |
| Regional cost rate cards        | Firestore `costCatalog/{region}` documents          |
| Default budget tier / currency  | `app/lib/core/constants/app_constants.dart`         |

## Development

```bash
# Flutter: static analysis and unit tests
cd app
flutter analyze
flutter test

# Cloud Functions: type-check / build and tests
cd functions
npm run build
npm test
```

## Deployment

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

Cloud Functions build automatically runs (`npm --prefix functions run build`)
as a predeploy hook — see `firebase.json`.

## Security

- The Gemini API key is stored as a Firebase Functions secret and never ships
  inside the app; all AI calls go through callable Cloud Functions.
- Firestore and Storage rules scope every document and file to its owning
  user (`ownerId` / `uid`).
- AI usage is rate-limited per user (server-side, transactional) and cached by
  prompt version to control cost and abuse.
- **Before production launch:** enable Firebase App Check and wire it into the
  Flutter client (`enforceAppCheck` is currently `false` in
  `functions/src/index.ts` for local development). If a Gemini key is ever
  pasted into a chat, doc, or commit, revoke it and issue a new one.

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
