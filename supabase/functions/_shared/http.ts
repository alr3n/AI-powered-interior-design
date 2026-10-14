// Shared HTTP plumbing for the AI Edge Functions: CORS, error shape, auth and
// per-user rate limiting. Errors are returned as
//   { "error": { "code": "<code>", "message": "<user-safe text>" } }
// and the Flutter client maps `status` / `code` to typed failures.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export const RATE_LIMIT_PER_HOUR = 30;

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export class HttpError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
  ) {
    super(message);
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Service-role client. Never expose this key or return it to callers. */
export function adminClient(): SupabaseClient {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) {
    throw new HttpError(500, "internal", "Server is not configured.");
  }
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Verifies the caller's access token and returns their user id. */
export async function requireUser(
  req: Request,
  admin: SupabaseClient,
): Promise<string> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "")
    .trim();
  if (!token) throw new HttpError(401, "unauthenticated", "Sign in required.");
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) {
    throw new HttpError(401, "unauthenticated", "Sign in required.");
  }
  return data.user.id;
}

/** Atomic hourly quota, enforced in Postgres (`consume_ai_call`). */
export async function checkRateLimit(
  admin: SupabaseClient,
  uid: string,
): Promise<void> {
  const { data, error } = await admin.rpc("consume_ai_call", {
    p_user: uid,
    p_limit: RATE_LIMIT_PER_HOUR,
  });
  if (error) {
    console.error("rate limit rpc failed", error);
    throw new HttpError(500, "internal", "Could not verify usage limits.");
  }
  if (data !== true) {
    throw new HttpError(
      429,
      "resource-exhausted",
      "AI request limit reached. Try again in a bit.",
    );
  }
}

export async function readJson(req: Request): Promise<Record<string, unknown>> {
  try {
    const body = await req.json();
    if (body && typeof body === "object" && !Array.isArray(body)) {
      return body as Record<string, unknown>;
    }
  } catch { /* fall through */ }
  throw new HttpError(400, "invalid-argument", "Request body must be JSON.");
}

/**
 * Wraps a handler with CORS + uniform error handling. The handler receives the
 * authenticated, rate-limited user id.
 */
export function serveAi(
  handler: (
    ctx: { uid: string; admin: SupabaseClient; body: Record<string, unknown> },
  ) => Promise<unknown>,
): void {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (req.method !== "POST") {
      return json(
        { error: { code: "invalid-argument", message: "Use POST." } },
        405,
      );
    }
    try {
      const admin = adminClient();
      const uid = await requireUser(req, admin);
      const body = await readJson(req);
      await checkRateLimit(admin, uid);
      return json(await handler({ uid, admin, body }));
    } catch (e) {
      if (e instanceof HttpError) {
        return json({ error: { code: e.code, message: e.message } }, e.status);
      }
      console.error("unhandled error", e);
      return json(
        { error: { code: "internal", message: "Something went wrong." } },
        500,
      );
    }
  });
}
