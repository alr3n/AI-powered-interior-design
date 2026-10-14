// Gemini access (REST) + response cache. The API key is a Supabase secret:
//   supabase secrets set GEMINI_API_KEY=...
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { HttpError } from "./http.ts";
import { PROMPT_VERSION } from "./prompts.ts";

export const FLASH = "gemini-2.5-flash";
export const PRO = "gemini-2.5-pro";
const CACHE_TTL_DAYS = 30;

/** The REST API documents upper-case type names (STRING, OBJECT, ...). */
function toGeminiSchema(node: unknown): unknown {
  if (Array.isArray(node)) return node.map(toGeminiSchema);
  if (node && typeof node === "object") {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(node)) {
      out[k] = k === "type" && typeof v === "string"
        ? v.toUpperCase()
        : toGeminiSchema(v);
    }
    return out;
  }
  return node;
}

interface GeminiResponse {
  candidates?: { content?: { parts?: { text?: string }[] } }[];
}

async function generate(opts: {
  model: string;
  system: string;
  parts: object[];
  schema?: object;
}): Promise<string> {
  const key = Deno.env.get("GEMINI_API_KEY");
  if (!key) throw new HttpError(500, "internal", "AI service is not configured.");

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${opts.model}:generateContent`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": key },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: opts.system }] },
        contents: [{ role: "user", parts: opts.parts }],
        generationConfig: opts.schema
          ? {
            responseMimeType: "application/json",
            responseSchema: toGeminiSchema(opts.schema),
          }
          : {},
      }),
    },
  );
  if (!res.ok) {
    console.error("gemini error", res.status, (await res.text()).slice(0, 500));
    if (res.status === 429 || res.status >= 500) {
      throw new HttpError(503, "unavailable", "The AI service is busy. Try again shortly.");
    }
    throw new HttpError(502, "internal", "The AI service had a problem. Try again.");
  }
  const data = (await res.json()) as GeminiResponse;
  return (data.candidates?.[0]?.content?.parts ?? [])
    .map((p) => p.text ?? "").join("");
}

export async function callGemini(opts: {
  model: string;
  system: string;
  parts: object[];
  schema?: object;
}): Promise<unknown> {
  let text = await generate(opts);
  if (!opts.schema) return text;
  try {
    return JSON.parse(text);
  } catch {
    // one retry on malformed JSON
    text = await generate(opts);
    try {
      return JSON.parse(text);
    } catch {
      throw new HttpError(502, "internal", "AI returned invalid data. Please retry.");
    }
  }
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(input),
  );
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** Response cache keyed by prompt version + task + payload (30-day TTL). */
export async function withCache<T>(
  admin: SupabaseClient,
  task: string,
  model: string,
  payload: unknown,
  produce: () => Promise<T>,
): Promise<T> {
  const key = await sha256Hex(
    `${PROMPT_VERSION}:${task}:${JSON.stringify(payload)}`,
  );
  const { data: hit } = await admin
    .from("ai_cache")
    .select("response")
    .eq("key", key)
    .gt("expires_at", new Date().toISOString())
    .maybeSingle();
  if (hit) return hit.response as T;

  const response = await produce();
  const { error } = await admin.from("ai_cache").upsert({
    key,
    task,
    model,
    response,
    created_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + CACHE_TTL_DAYS * 864e5).toISOString(),
  });
  if (error) console.error("cache write failed", error); // non-fatal
  return response;
}

export async function loadRateCard(
  admin: SupabaseClient,
  region: string,
): Promise<{ currency: string; rates: unknown }> {
  const { data } = await admin
    .from("cost_catalog")
    .select("currency, rates")
    .eq("region", region)
    .maybeSingle();
  return data ?? { currency: "PHP", rates: {} };
}
