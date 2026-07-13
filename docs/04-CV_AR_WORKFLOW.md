# Computer Vision & AR Workflow

## v1 pipeline (hybrid: photos + ARCore measurement)

### Stage 1 — Guided capture (camera package)
Coverage checklist drives the flow; each target is one or more tagged shots:

| Target | Shots | Guidance overlay |
|---|---|---|
| Walls N/E/S/W | 1 each | "Stand back, fit the whole wall" |
| Floor | 1–2 | "Angle down 45°, include furniture feet" |
| Ceiling | 1 | "Include at least one wall edge" |
| Windows / doors | 1 each | "Fill ~60% of frame" |
| Furniture | 2 wide | "Two corners of the room" |

- Live checks: exposure (reject too-dark via luma histogram), blur (Laplacian
  variance through a small platform-channel/ML Kit check — v1 ships luma only),
  progress ring shows coverage %.
- Compression: flutter_image_compress → max 1280px, JPEG q80 (~200–400 KB).
- Shots + device orientation (sensors from `camera` metadata) queue for upload.

### Stage 2 — ARCore measurement (ar_flutter_plugin_2)
1. Plane detection on the floor; user taps each floor corner → floor polygon.
2. Wall lengths = polygon edges; area via shoelace formula.
3. Ceiling height: tap floor point then the ceiling directly above (hit-test on
   detected ceiling plane, or manual slider fallback for devices without
   depth-assisted ceiling planes).
4. Output: `dimensions{l,w,h}`, `floorPolygon[]`, flagged `dimensionSource: "ar"`.
5. Fallback: if ARCore unsupported (checked via ArCoreApk availability), user
   enters dimensions manually (`dimensionSource: "manual"`), or accepts AI
   estimates (`"ai"`, lowest trust).

### Stage 3 — Server-side Gemini vision (T1)
Images (Storage URLs → function downloads → inline base64 parts) + AR dims →
structured extraction: furniture inventory with approximate dims, materials with
confidence, openings per wall, lighting observation. AR dims are ground truth;
the model scales furniture to be consistent.

Why Gemini vision instead of on-device ML Kit object detection for v1:
ML Kit's base object detector gives generic labels ("home good") — useless for
"wardrobe vs cabinet". Gemini identifies category, style, material, and
approximate size in one call. ML Kit remains in the stack for *on-device* live
checks (blur/label sanity) where latency matters; it is optional in v1.

### Stage 4 — Reconciliation & RoomModel build (Dart, isolate)
- Merge AR dims over AI estimates; compute floor/wall/ceiling areas.
- Furniture footprint sum → occupied %; free-area polygon for walkway analysis.
- Persist RoomModel (version++), photos already in Storage.

## Derived quantities (features/quantities)
```
floorArea      = shoelace(floorPolygon)            (or l×w fallback)
wallAreaGross  = perimeter × height
wallAreaNet    = gross − Σ openings
ceilingArea    = floorArea
paintLiters    = wallAreaNet / 10 m²/L × coats(2) × 1.1 waste
tiles          = ceil(floorArea / tileArea × 1.10)  (10% waste, 15% diagonal)
flooringM2     = floorArea × 1.08
```
All labeled "estimates for planning — verify on site; not a substitute for a
professional take-off or code compliance review."

## v2 — AR visualization & 3D reconstruction (roadmap)
- **Furniture placement AR**: anchor GLB models (Sceneform-compatible) on the
  detected floor; gestures: drag = reposition, pinch = scale (clamped to real
  product dims), palette swaps material albedo. Layout saved as
  anchors+transforms JSON per design.
- **Before/after renders**: Gemini image generation from a scan photo +
  design concept prompt; slider comparison widget already stubbed.
- **3D mesh**: ARCore Depth API point clouds → server-side Poisson
  reconstruction, or Scene Semantics API when broadly available. Highest effort;
  gated on v1 traction.

## Device support matrix
| Capability | Requirement | Fallback |
|---|---|---|
| Guided capture | any camera | — |
| AR measure | ARCore-certified device | manual entry |
| Depth occlusion (v2) | Depth API device | no occlusion |
