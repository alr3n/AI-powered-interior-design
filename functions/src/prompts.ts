/**
 * All Gemini prompts + response schemas. Versioned so cached responses can be
 * invalidated when a prompt changes.
 */
export const PROMPT_VERSION = 1;

const score = { type: "integer", minimum: 0, maximum: 100 } as const;
const conf = { type: "number", minimum: 0, maximum: 1 } as const;

export const SYSTEM = {
  vision: `You are a computer-vision assistant for interior analysis.
Extract only what is visible in the photos. Give confidence 0-1 per item.
If AR-measured dimensions are provided they are ground truth: NEVER override
them, and scale all furniture size estimates to be consistent with them.
List every assumption you make in "assumptions".`,

  analysis: `You are a senior interior designer and space planner.
Score each of the 13 categories 0-100 with specific reference to THIS room's
dimensions and furniture (cite them by name). The overall score is your weighted
professional judgment, not an average. Recommendations must be actionable with
rough costs in {currency} using ONLY the provided rate card for unit prices.
Clearance and accessibility observations are guidance only - explicitly avoid
claiming building-code compliance or structural certification.
List assumptions in "assumptions".`,

  design: `You are an interior designer generating a {style} redesign concept
for the exact room described. The palette must harmonize with retained elements.
Budget must fit the {tier} tier using the provided rate card. HEX codes required
for every palette color.`,

  chat: `You are SpaceSense, a friendly expert interior consultant.
CURRENT_ROOM data follows; answer using its real numbers.
Paint: liters = netWallArea / 10 (m2 per liter) * 2 coats * 1.1 waste - show the math.
If a question needs a professional (structural, electrical load, plumbing) or a
new scan, say so plainly. Keep answers under 150 words unless asked for detail.`,
};

export const SCHEMAS: Record<string, object> = {
  vision: {
    type: "object",
    properties: {
      roomType: { type: "string" },
      dimensionEstimate: {
        type: "object",
        properties: { lengthM: { type: "number" }, widthM: { type: "number" },
          heightM: { type: "number" }, confidence: conf },
        required: ["lengthM", "widthM", "heightM", "confidence"],
      },
      furniture: {
        type: "array",
        items: {
          type: "object",
          properties: {
            category: { type: "string" }, label: { type: "string" },
            approxDims: { type: "object", properties: {
              l: { type: "number" }, w: { type: "number" }, h: { type: "number" } } },
            confidence: conf,
          },
          required: ["category", "label", "confidence"],
        },
      },
      materials: {
        type: "array",
        items: { type: "object", properties: {
          surface: { type: "string" }, material: { type: "string" }, confidence: conf },
          required: ["surface", "material", "confidence"] },
      },
      openings: {
        type: "array",
        items: { type: "object", properties: {
          type: { type: "string", enum: ["door", "window"] },
          widthM: { type: "number" }, heightM: { type: "number" } },
          required: ["type"] },
      },
      lightingObservation: { type: "string" },
      assumptions: { type: "array", items: { type: "string" } },
    },
    required: ["roomType", "furniture", "materials", "assumptions"],
  },

  analysis: {
    type: "object",
    properties: {
      overallScore: score,
      categoryScores: {
        type: "object",
        properties: Object.fromEntries([
          "functionality", "ergonomics", "trafficFlow", "lighting",
          "furnitureArrangement", "spaceUtilization", "storage", "visualBalance",
          "colorHarmony", "accessibility", "sustainability", "comfort", "safety",
        ].map((k) => [k, score])),
      },
      strengths: { type: "array", items: { type: "string" } },
      weaknesses: { type: "array", items: { type: "string" } },
      recommendations: {
        type: "array",
        items: { type: "object", properties: {
          title: { type: "string" }, detail: { type: "string" },
          priority: { type: "string", enum: ["high", "medium", "low"] },
          estCost: { type: "number" } },
          required: ["title", "detail", "priority"] },
      },
      assumptions: { type: "array", items: { type: "string" } },
    },
    required: ["overallScore", "categoryScores", "strengths", "weaknesses",
      "recommendations", "assumptions"],
  },

  design: {
    type: "object",
    properties: {
      style: { type: "string" },
      mood: { type: "string" },
      palette: { type: "array", items: { type: "object", properties: {
        hex: { type: "string" }, role: { type: "string" } },
        required: ["hex", "role"] } },
      materials: { type: "array", items: { type: "string" } },
      flooring: { type: "string" },
      wallFinish: { type: "string" },
      furniture: { type: "array", items: { type: "object", properties: {
        item: { type: "string" }, estPrice: { type: "number" },
        priority: { type: "string", enum: ["core", "optional"] } },
        required: ["item", "priority"] } },
      lighting: { type: "array", items: { type: "string" } },
      decor: { type: "array", items: { type: "string" } },
      budgetTotal: { type: "number" },
      difficulty: { type: "string", enum: ["easy", "moderate", "hard"] },
      maintenance: { type: "string", enum: ["low", "medium", "high"] },
    },
    required: ["style", "mood", "palette", "furniture", "budgetTotal",
      "difficulty", "maintenance"],
  },
};
