// T9: context-aware chat (stateless; history supplied by the client).
import { serveAi, HttpError } from "../_shared/http.ts";
import { callGemini, FLASH } from "../_shared/gemini.ts";
import { SYSTEM } from "../_shared/prompts.ts";

const MAX_TEXT = 4000;

serveAi(async ({ body }) => {
  const message = typeof body.message === "string" ? body.message.trim() : "";
  if (!message) throw new HttpError(400, "failed-precondition", "Empty message.");
  if (message.length > MAX_TEXT) {
    throw new HttpError(400, "invalid-argument", "Message is too long.");
  }

  const history = Array.isArray(body.history) ? body.history : [];
  const transcript = history.slice(-20)
    .filter((m) => m && (m.role === "user" || m.role === "model") && typeof m.text === "string")
    .map((m) => `${m.role.toUpperCase()}: ${String(m.text).slice(0, MAX_TEXT)}`)
    .join("\n");

  const text = await callGemini({
    model: FLASH,
    system: SYSTEM.chat,
    parts: [{
      text: `CURRENT_ROOM:\n${JSON.stringify(body.room ?? {})}\n\nHISTORY:\n${transcript}\n\nUSER: ${message}`,
    }],
  });
  return { reply: text };
});
