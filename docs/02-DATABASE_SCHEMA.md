# Firestore Schema

## Collections

### users/{uid}
```json
{
  "displayName": "string",
  "email": "string",
  "photoUrl": "string?",
  "isGuest": false,
  "region": "PH",
  "currency": "PHP",
  "preferences": { "themeMode": "system", "budgetTier": "medium", "occupants": 2,
                   "hasChildren": false, "hasPets": false, "accessibilityNeeds": [] },
  "createdAt": "timestamp",
  "aiUsage": { "hourWindowStart": "timestamp", "callsThisWindow": 0 }
}
```

### projects/{projectId}
```json
{
  "ownerId": "uid",
  "name": "Master Bedroom Reno",
  "roomType": "bedroom",
  "status": "scanned | analyzed | designed | archived",
  "coverPhotoUrl": "string?",
  "location": { "lat": 0, "lng": 0, "label": "string" },   // optional
  "createdAt": "timestamp", "updatedAt": "timestamp",
  "isFavorite": false
}
```

### projects/{projectId}/rooms/{roomId}
The reconstructed room model. `dimensionSource` records whether numbers came
from AR measurement (authoritative) or AI estimate.
```json
{
  "version": 3,
  "dimensionSource": "ar | ai | manual",
  "dimensions": { "lengthM": 4.2, "widthM": 3.5, "heightM": 2.7 },
  "floorPolygon": [{ "x": 0, "y": 0 }],
  "walls": [{ "id": "w1", "lengthM": 4.2, "openings": [
      { "type": "door|window", "widthM": 0.9, "heightM": 2.1, "positionM": 1.2 }]}],
  "furniture": [{
     "id": "f1", "category": "bed", "label": "Queen bed",
     "approxDims": { "l": 2.0, "w": 1.5, "h": 0.5 },
     "footprintM2": 3.0, "confidence": 0.9,
     "position": { "x": 0.5, "y": 1.0 } }],
  "materials": [{ "surface": "floor", "material": "tiles", "confidence": 0.85 }],
  "lighting": { "windowOrientation": "SE", "naturalScore": 62, "artificialFixtures": 2 },
  "photoRefs": [{ "storagePath": "users/{uid}/projects/{pid}/scan/w1.jpg", "target": "wall_north" }],
  "scanCoverage": { "walls": 4, "floor": true, "ceiling": true, "windows": true, "doors": true },
  "createdAt": "timestamp", "updatedAt": "timestamp"
}
```

### projects/{projectId}/analyses/{analysisId}
Gemini output, stored verbatim + metadata.
```json
{
  "roomVersion": 3, "model": "gemini-2.5-pro",
  "overallScore": 88,
  "categoryScores": { "functionality": 85, "ergonomics": 80, "trafficFlow": 78,
    "lighting": 90, "furnitureArrangement": 82, "spaceUtilization": 75,
    "storage": 70, "visualBalance": 88, "colorHarmony": 91,
    "accessibility": 72, "sustainability": 68, "comfort": 86, "safety": 89 },
  "strengths": ["..."], "weaknesses": ["..."],
  "recommendations": [{ "title": "...", "detail": "...", "priority": "high|medium|low",
                        "estCostPhp": 4500 }],
  "createdAt": "timestamp"
}
```

### projects/{projectId}/designs/{designId}
One generated style concept.
```json
{
  "style": "japandi", "roomVersion": 3,
  "mood": "string",
  "palette": [{ "hex": "#E8E2D5", "role": "walls", "contrastOnWhite": 1.3 }],
  "materials": ["white oak", "linen"], "flooring": "engineered oak",
  "wallFinish": "limewash paint",
  "furniture": [{ "item": "low platform bed", "estPricePhp": 25000, "priority": "core" }],
  "lighting": ["paper pendant", "2700K LED strips"],
  "decor": ["..."],
  "budget": { "tier": "medium", "totalPhp": 120000 },
  "difficulty": "moderate", "maintenance": "low",
  "createdAt": "timestamp"
}
```

### projects/{projectId}/costEstimates/{estimateId}
```json
{
  "tier": "low|medium|premium|luxury", "currency": "PHP",
  "lines": [{ "category": "paint", "qty": 34.6, "unit": "m2", "unitCost": 180,
              "labor": 2500, "total": 8728 }],
  "totals": { "materials": 95000, "labor": 42000, "contingencyPct": 10, "grand": 150700 },
  "createdAt": "timestamp"
}
```

### projects/{projectId}/chats/{messageId}
```json
{ "role": "user|model", "text": "string", "roomVersion": 3, "createdAt": "timestamp" }
```

### aiCache/{cacheKey}          — server-only (rules deny client access)
```json
{ "task": "analysis", "hash": "sha256(...)", "response": { }, "model": "…",
  "createdAt": "timestamp", "expiresAt": "timestamp" }
```

### designTips/{tipId}          — public read, admin write
```json
{ "text": "...", "category": "lighting", "activeDate": "2026-07-12" }
```

### costCatalog/{region}        — public read, admin write. PHP unit rates.
```json
{ "region": "PH", "currency": "PHP",
  "rates": { "paint_m2": {"low":120,"medium":180,"premium":260,"luxury":420},
             "tile_m2":  {"low":450,"medium":800,"premium":1500,"luxury":3500},
             "labor_paint_m2": {"low":60,"medium":90,"premium":120,"luxury":180} } }
```

## Storage layout
```
users/{uid}/projects/{projectId}/scan/{shotId}.jpg      (≤10MB, image/*)
users/{uid}/projects/{projectId}/renders/{id}.png       (v2: generated renders)
users/{uid}/projects/{projectId}/reports/{id}.pdf
```

## Composite indexes (firebase/firestore.indexes.json)
- projects: (ownerId ASC, updatedAt DESC)
- projects: (ownerId ASC, isFavorite DESC, updatedAt DESC)

## Access model
Everything under `projects/*` requires `ownerId == request.auth.uid`
(subcollections check the parent doc). Guests (anonymous auth) get full
functionality; their data migrates on account-link via
`linkWithCredential`, which preserves the uid — no data copy needed.
