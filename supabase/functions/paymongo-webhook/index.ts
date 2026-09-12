// Supabase Edge Function: paymongo-webhook
// Secure, idempotent PayMongo webhook handler with Web Crypto HMAC-SHA256 verification
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const WEBHOOK_SECRET = Deno.env.get("PAYMONGO_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Timing-safe constant time string comparison to prevent timing attacks
export function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

// Compute HMAC-SHA256 digest hex string using Web Crypto API
export async function computeHmacSha256Hex(key: string, data: string): Promise<string> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(data));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Parse Paymongo-Signature header format: t=1234567890,te=abcdef...,li=...
export function parseSignatureHeader(header: string): Record<string, string> {
  const parts = header.split(",");
  const map: Record<string, string> = {};
  for (const part of parts) {
    const [k, ...v] = part.split("=");
    if (k && v.length > 0) {
      map[k.trim()] = v.join("=").trim();
    }
  }
  return map;
}

serve(async (req: Request): Promise<Response> => {
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  const signatureHeader = req.headers.get("Paymongo-Signature") ?? "";
  if (!signatureHeader || !WEBHOOK_SECRET) {
    return new Response(
      JSON.stringify({ error: "Missing Paymongo-Signature header or webhook secret is unconfigured" }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  const rawBody = await req.text();
  const parsedHeader = parseSignatureHeader(signatureHeader);
  const tStr = parsedHeader["t"];
  if (!tStr) {
    return new Response(
      JSON.stringify({ error: "Missing timestamp parameter 't' in Paymongo-Signature header" }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  const t = parseInt(tStr, 10);
  if (isNaN(t)) {
    return new Response(
      JSON.stringify({ error: "Invalid timestamp in signature header" }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  // Verify timestamp freshness within 300s window to prevent replay attacks
  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - t) > 300) {
    return new Response(
      JSON.stringify({ error: "Signature timestamp expired: tolerance window is 300 seconds" }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  let payload: any;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return new Response(JSON.stringify({ error: "Malformed JSON payload in request body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const isLive = payload?.data?.attributes?.livemode === true;
  const targetSig = isLive
    ? (parsedHeader["li"] ?? parsedHeader["te"])
    : (parsedHeader["te"] ?? parsedHeader["li"]);

  const stringToSign = `${t}.${rawBody}`;
  const computedSig = await computeHmacSha256Hex(WEBHOOK_SECRET, stringToSign);

  if (!targetSig || !timingSafeEqual(computedSig.toLowerCase(), targetSig.toLowerCase())) {
    return new Response(
      JSON.stringify({ error: "Cryptographic HMAC-SHA256 signature verification failed" }),
      {
        status: 401,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  // Extract relevant event identifiers
  const eventId = payload?.data?.id ?? "";
  const eventType = payload?.data?.attributes?.type ?? "";
  const innerData = payload?.data?.attributes?.data ?? {};
  const resourceId = innerData?.id ?? "";
  const metadata = innerData?.attributes?.metadata ?? {};
  const bookingId = metadata?.booking_id ?? innerData?.attributes?.reference_number ?? null;

  // Initialize service-role Supabase client to call process_paymongo_webhook RPC
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { data: rpcResult, error: rpcError } = await supabase.rpc("process_paymongo_webhook", {
    p_event_id: eventId,
    p_event_type: eventType,
    p_resource_id: resourceId,
    p_booking_id: bookingId,
    p_payload: payload,
  });

  if (rpcError) {
    console.error("RPC Error processing webhook:", rpcError);
    return new Response(
      JSON.stringify({ error: rpcError.message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  // Return HTTP 200 with result (handles both initial processing and idempotent replay)
  return new Response(
    JSON.stringify({
      received: true,
      result: rpcResult,
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }
  );
});
