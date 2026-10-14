// T2: room model -> 13-category analysis.
import { serveAi, HttpError } from "../_shared/http.ts";
import { callGemini, loadRateCard, PRO, withCache } from "../_shared/gemini.ts";
import { SCHEMAS, SYSTEM } from "../_shared/prompts.ts";

serveAi(async ({ admin, body }) => {
  const room = body.room;
  if (!room || typeof room !== "object") {
    throw new HttpError(400, "failed-precondition", "Room model required.");
  }
  const profile = body.profile ?? {};
  const region = typeof body.region === "string" && /^[A-Z]{2}$/.test(body.region)
    ? body.region
    : "PH";

  const rateCard = await loadRateCard(admin, region);
  return await withCache(admin, "analysis", PRO, { room, profile, region }, () =>
    callGemini({
      model: PRO,
      // function replacer: the currency string is never treated as a pattern
      system: SYSTEM.analysis.replace("{currency}", () => rateCard.currency),
      parts: [{
        text: `ROOM_DATA:\n${JSON.stringify(room)}\n\nUSER_PROFILE:\n${
          JSON.stringify(profile)
        }\n\nRATE_CARD:\n${JSON.stringify(rateCard)}`,
      }],
      schema: SCHEMAS.analysis,
    }));
});
