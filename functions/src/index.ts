import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { GoogleGenAI } from "@google/genai";
import { createHash } from "crypto";
import { SYSTEM, SCHEMAS, PROMPT_VERSION } from "./prompts";

initializeApp();
const db = getFirestore();
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

const FLASH = "gemini-2.5-flash";
const PRO = "gemini-2.5-pro";
const RATE_LIMIT_PER_HOUR = 30;
const CACHE_TTL_DAYS = 30;

// ---------- helpers ----------------------------------------------------------

function requireAuth(req: CallableRequest): string {
  if (!req.auth) throw new HttpsError("unauthenticated", "Sign in required.");
  return req.auth.uid;
}

/** Transactional sliding-window rate limiter on users/{uid}.aiUsage */
async function checkRateLimit(uid: string): Promise<void> {
  const ref = db.doc(`users/${uid}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Timestamp.now();
    const usage = snap.get("aiUsage") ?? {};
    const windowStart: Timestamp | undefined = usage.hourWindowStart;
    const inWindow = windowStart && now.seconds - windowStart.seconds < 3600;
    const calls = inWindow ? (usage.callsThisWindow ?? 0) : 0;
    if (calls >= RATE_LIMIT_PER_HOUR) {
      throw new HttpsError("resource-exhausted",
        "AI request limit reached. Try again in a bit.");
    }
    tx.set(ref, {
      aiUsage: {
        hourWindowStart: inWindow ? windowStart : now,
        callsThisWindow: calls + 1,
      },
    }, { merge: true });
  });
}

function cacheKey(task: string, payload: unknown): string {
  return createHash("sha256")
    .update(`${PROMPT_VERSION}:${task}:${JSON.stringify(payload)}`)
    .digest("hex");
}

async function withCache<T>(task: string, payload: unknown,
  produce: () => Promise<T>): Promise<T> {
  const key = cacheKey(task, payload);
  const ref = db.doc(`aiCache/${key}`);
  const hit = await ref.get();
  if (hit.exists && hit.get("expiresAt").toMillis() > Date.now()) {
    return hit.get("response") as T;
  }
  const response = await produce();
  await ref.set({
    task, response, model: task === "analysis" || task === "design" ? PRO : FLASH,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + CACHE_TTL_DAYS * 864e5),
  });
  return response;
}

async function callGemini(opts: {
  model: string; system: string; parts: object[]; schema?: object;
}): Promise<unknown> {
  const ai = new GoogleGenAI({ apiKey: GEMINI_API_KEY.value() });
  const gen = async () => ai.models.generateContent({
    model: opts.model,
    contents: [{ role: "user", parts: opts.parts }],
    config: {
      systemInstruction: opts.system,
      ...(opts.schema
        ? { responseMimeType: "application/json", responseSchema: opts.schema }
        : {}),
    },
  });
  let res = await gen();
  let text = res.text ?? "";
  if (opts.schema) {
    try { return JSON.parse(text); } catch {
      // one retry on malformed JSON
      res = await gen();
      text = res.text ?? "";
      try { return JSON.parse(text); } catch {
        throw new HttpsError("internal", "AI returned invalid data. Please retry.");
      }
    }
  }
  return text;
}

async function loadRateCard(region: string): Promise<object> {
  const snap = await db.doc(`costCatalog/${region}`).get();
  return snap.exists ? snap.data()! : { currency: "PHP", rates: {} };
}

const callOpts = { secrets: [GEMINI_API_KEY], enforceAppCheck: false, // set true in prod
  memory: "512MiB" as const, timeoutSeconds: 120 };

// ---------- callable endpoints ----------------------------------------------

/** T1: photos (+ optional AR dims) -> structured room extraction */
export const extractRoom = onCall(callOpts, async (req) => {
  const uid = requireAuth(req);
  await checkRateLimit(uid);
  const { images, arDimensions } = req.data as {
    images: { base64: string; mimeType: string; target: string }[];
    arDimensions?: object;
  };
  if (!images?.length) {
    throw new HttpsError("failed-precondition", "No scan photos provided.");
  }
  const parts: object[] = images.slice(0, 12).map((i) => ({
    inlineData: { data: i.base64, mimeType: i.mimeType },
  }));
  parts.push({
    text: `Photo targets in order: ${images.map((i) => i.target).join(", ")}.` +
      (arDimensions
        ? `\nAR_MEASURED_DIMENSIONS (ground truth): ${JSON.stringify(arDimensions)}`
        : "\nNo measured dimensions; estimate from photos."),
  });
  // images make each call unique; hash only targets+dims for cache (skip cache here)
  return callGemini({ model: FLASH, system: SYSTEM.vision, parts,
    schema: SCHEMAS.vision });
});

/** T2: room model -> 13-category analysis */
export const analyzeRoom = onCall(callOpts, async (req) => {
  const uid = requireAuth(req);
  await checkRateLimit(uid);
  const { room, profile, region = "PH" } = req.data as {
    room: object & { version?: number }; profile?: object; region?: string;
  };
  if (!room) throw new HttpsError("failed-precondition", "Room model required.");
  const rateCard = await loadRateCard(region);
  return withCache("analysis", { room, profile, region }, () =>
    callGemini({
      model: PRO,
      system: SYSTEM.analysis.replace("{currency}", (rateCard as any).currency ?? "PHP"),
      parts: [{ text:
        `ROOM_DATA:\n${JSON.stringify(room)}\n\nUSER_PROFILE:\n${JSON.stringify(profile ?? {})}` +
        `\n\nRATE_CARD:\n${JSON.stringify(rateCard)}` }],
      schema: SCHEMAS.analysis,
    }));
});

/** T3: one design concept per call */
export const generateDesign = onCall(callOpts, async (req) => {
  const uid = requireAuth(req);
  await checkRateLimit(uid);
  const { room, style, tier = "medium", region = "PH" } = req.data as {
    room: object; style: string; tier?: string; region?: string;
  };
  if (!room || !style) {
    throw new HttpsError("failed-precondition", "Room and style required.");
  }
  const rateCard = await loadRateCard(region);
  return withCache("design", { room, style, tier, region }, () =>
    callGemini({
      model: PRO,
      system: SYSTEM.design.replace("{style}", style).replace("{tier}", tier),
      parts: [{ text:
        `ROOM_DATA:\n${JSON.stringify(room)}\n\nRATE_CARD:\n${JSON.stringify(rateCard)}` }],
      schema: SCHEMAS.design,
    }));
});

/** T9: context-aware chat (stateless; history supplied by client) */
export const chatAssistant = onCall(callOpts, async (req) => {
  const uid = requireAuth(req);
  await checkRateLimit(uid);
  const { room, history, message } = req.data as {
    room?: object;
    history: { role: "user" | "model"; text: string }[];
    message: string;
  };
  if (!message?.trim()) throw new HttpsError("failed-precondition", "Empty message.");
  const transcript = (history ?? []).slice(-20)
    .map((m) => `${m.role.toUpperCase()}: ${m.text}`).join("\n");
  const parts = [{ text:
    `CURRENT_ROOM:\n${JSON.stringify(room ?? {})}\n\nHISTORY:\n${transcript}` +
    `\n\nUSER: ${message}` }];
  const text = await callGemini({ model: FLASH, system: SYSTEM.chat, parts });
  return { reply: text };
});
