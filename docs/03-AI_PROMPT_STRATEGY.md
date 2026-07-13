# AI Prompt Engineering Strategy

All prompts live server-side in `functions/src/prompts.ts`. Client sends task +
structured room data only. Every call uses **JSON mode with a responseSchema**
so outputs parse deterministically — no regex extraction, no retry-on-malformed.

## Principles

1. **Structured in, structured out.** Room facts are serialized as compact JSON,
   not prose. Gemini receives `ROOM_DATA:` blocks with measured dims flagged
   `"source":"ar_measured"` so it treats them as ground truth, not estimates.
2. **Model routing.** Flash for vision extraction/chat (latency), Pro for the
   13-category analysis and design concepts (reasoning).
3. **Grounded numbers.** Cost figures come from `costCatalog` rates injected
   into the prompt; Gemini allocates, it does not invent unit prices.
4. **Refusal rails.** System prompts forbid claiming code compliance, structural
   safety certification, or exact measurements from photos alone.
5. **Caching.** Cache key = sha256(task + roomVersion + params). TTL 30 days.

## Task catalog

### T1 — Vision extraction (Flash, images + optional AR dims)
System: "You are a computer-vision assistant for interior analysis. Extract only
what is visible. Confidence 0–1 per item. If AR-measured dimensions are provided,
NEVER override them; scale furniture estimates to be consistent with them."
Output schema: roomType, dimensionEstimate{l,w,h, confidence}, furniture[],
materials[], openings[], lightingObservation.

### T2 — Interior analysis (Pro)
System: "You are a senior interior designer and space planner. Score 13
categories 0–100 with one-sentence justification each; overall score is your
weighted judgment, not an average. Be specific to THIS room's data — cite
dimensions and furniture by name. Recommendations must be actionable with rough
PHP costs using the provided rate card. Label all clearance/accessibility
observations as guidance, not code compliance."
Input: ROOM_DATA + RATE_CARD + user profile (occupants, children, pets,
accessibility needs). Output schema mirrors `analyses` doc.

### T3 — Design concepts (Pro, one call per style)
System: "Generate a {style} redesign concept for this exact room. Palette must
harmonize with retained elements: {kept furniture/floor}. HEX codes required.
Budget must fit tier {tier} using the rate card. Include difficulty and
maintenance ratings with reasons."
Output schema mirrors `designs` doc.

### T4 — Furniture recommendation (Flash)
Input adds budget ceiling + lifestyle flags. Rule: "Every item must physically
fit: check against room dims minus existing furniture footprints; show the
clearance math in `fitNote`." Output: shoppingList[{item, dims, estPricePhp,
fitNote, priority}].

### T5 — Color palettes (Flash)
"Derive 3 palettes from existing floor/furniture colors and window orientation
({orientation} light is {warm/cool}). Include WCAG contrast ratio of proposed
text-on-wall pairings."

### T6 — Lighting plan (Flash)
Input: dims, window orientation, fixture count. Output: layered plan (ambient/
task/accent), color temperatures, lumen targets by room type (bedroom ~150 lm/m²,
kitchen ~300 lm/m²), placement notes.

### T7 — Space optimization (Pro)
"Compute walkway widths from floor polygon minus furniture footprints. Flag
paths under 0.75 m. Propose max 3 alternative layouts as furniture position
lists (same coordinate system as input)."

### T8 — Sustainability audit (Flash)
Output: score /100, ventilation/daylight/material notes, plant suggestions,
solar note if top-floor/detached (ask, don't assume).

### T9 — Chat assistant (Flash, multi-turn)
System: "You are SpaceSense, a friendly interior consultant. CURRENT_ROOM
context follows; answer with its numbers. For quantity questions use the
formulas: paint L = wallArea/coverage(10 m²/L)×coats; state assumptions.
If asked something requiring a new scan or a pro (structural, electrical
load), say so." History: last 20 turns, trimmed to fit context. Room context
re-injected each call (stateless functions).

### T10 — Report narrative (Pro)
Consolidates T2/T3/T6/T8 outputs into report-ready prose sections. Client
composes the PDF locally from this JSON (see reports feature).

## Anti-hallucination checklist applied to every schema
- numeric fields bounded (scores 0–100, confidence 0–1)
- enums for categories/styles/materials
- `assumptions: string[]` field required — surfaced in UI
- server validates schema before caching; invalid → single retry with
  "Your previous output failed validation: {error}" then typed failure.
