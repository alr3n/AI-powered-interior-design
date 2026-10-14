// T3: one design concept per call.
import { serveAi, HttpError } from "../_shared/http.ts";
import { callGemini, loadRateCard, PRO, withCache } from "../_shared/gemini.ts";
import { BUDGET_TIERS, DESIGN_STYLES, SCHEMAS, SYSTEM } from "../_shared/prompts.ts";

serveAi(async ({ admin, body }) => {
  const room = body.room;
  const style = body.style;
  const tier = body.tier ?? "medium";
  if (!room || typeof room !== "object" || typeof style !== "string") {
    throw new HttpError(400, "failed-precondition", "Room and style required.");
  }
  // Only known values may reach the system prompt (prompt-injection guard).
  if (!DESIGN_STYLES.includes(style)) {
    throw new HttpError(400, "invalid-argument", "Unknown design style.");
  }
  if (typeof tier !== "string" || !BUDGET_TIERS.includes(tier)) {
    throw new HttpError(400, "invalid-argument", "Unknown budget tier.");
  }
  const region = typeof body.region === "string" && /^[A-Z]{2}$/.test(body.region)
    ? body.region
    : "PH";

  const rateCard = await loadRateCard(admin, region);
  return await withCache(admin, "design", PRO, { room, style, tier, region }, () =>
    callGemini({
      model: PRO,
      system: SYSTEM.design.replace("{style}", () => style).replace("{tier}", () => tier),
      parts: [{
        text: `ROOM_DATA:\n${JSON.stringify(room)}\n\nRATE_CARD:\n${JSON.stringify(rateCard)}`,
      }],
      schema: SCHEMAS.design,
    }));
});
