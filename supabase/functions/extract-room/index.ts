// T1: photos (+ optional measured dims) -> structured room extraction.
import { serveAi, HttpError } from "../_shared/http.ts";
import { callGemini, FLASH } from "../_shared/gemini.ts";
import { SCHEMAS, SYSTEM } from "../_shared/prompts.ts";

const MAX_IMAGES = 12;
const MAX_IMAGE_B64_CHARS = 6_000_000; // ~4.5 MB decoded
const MIME_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

interface ImageIn {
  base64: string;
  mimeType: string;
  target: string;
}

serveAi(async ({ body }) => {
  const images = body.images as ImageIn[] | undefined;
  if (!Array.isArray(images) || images.length === 0) {
    throw new HttpError(400, "failed-precondition", "No scan photos provided.");
  }
  const used = images.slice(0, MAX_IMAGES);
  for (const i of used) {
    if (
      typeof i?.base64 !== "string" || i.base64.length === 0 ||
      i.base64.length > MAX_IMAGE_B64_CHARS || !MIME_TYPES.has(i.mimeType)
    ) {
      throw new HttpError(400, "invalid-argument", "A scan photo was invalid.");
    }
  }
  const arDimensions = body.arDimensions;

  const parts: object[] = used.map((i) => ({
    inlineData: { data: i.base64, mimeType: i.mimeType },
  }));
  const targets = used.map((i) => String(i.target ?? "").slice(0, 40)).join(", ");
  parts.push({
    text: `Photo targets in order: ${targets}.` +
      (arDimensions
        ? `\nAR_MEASURED_DIMENSIONS (ground truth): ${JSON.stringify(arDimensions)}`
        : "\nNo measured dimensions; estimate from photos."),
  });

  // Photos make every call unique, so this endpoint is deliberately uncached.
  return await callGemini({
    model: FLASH,
    system: SYSTEM.vision,
    parts,
    schema: SCHEMAS.vision,
  });
});
