# SpaceSense AI

AI-powered interior scanning, analysis, and redesign app. Flutter + Firebase + Google Gemini.

## Repository layout

```
docs/          Architecture, schema, AI prompts, CV/AR workflow, implementation guide
app/           Flutter application (run `flutter create .` inside to generate platform folders)
functions/     Firebase Cloud Functions (TypeScript) — the ONLY place Gemini is called
firebase/      Firestore/Storage security rules and indexes
```

## Quick start

1. Read `docs/05-IMPLEMENTATION_GUIDE.md` — it walks setup end to end.
2. Create a Firebase project, enable Auth (Google + Email + Anonymous), Firestore, Storage.
3. `cd app && flutter create . && flutterfire configure && flutter pub get && flutter run`
4. `cd functions && npm i && firebase functions:secrets:set GEMINI_API_KEY && firebase deploy --only functions`

## Security note

Never ship a Gemini API key in the app. All AI calls go through callable Cloud Functions
(App Check enforced, per-user rate limited). If a key was ever pasted into a chat, doc,
or commit, revoke it and issue a new one.

## v1 scope (this codebase)

- Auth: Google, email, guest
- Hybrid scan: guided multi-photo capture + ARCore plane-detection measurements
- Gemini room analysis (score /100, strengths, weaknesses, recommendations)
- Design concept generator (12 styles)
- Furniture, color, lighting, space-optimization recommendations
- Civil engineering quantity take-offs (paint, tile, flooring) — labeled guidance, not code compliance
- Cost estimation (PHP default, 4 budget tiers)
- Sustainability scoring
- Context-aware AI chat assistant
- PDF report export

v2 roadmap (AR furniture placement, before/after image generation, 3D reconstruction) is in
`docs/05-IMPLEMENTATION_GUIDE.md`.
