// CORS headers for Supabase Edge Functions
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS, DELETE, PATCH",
};

/**
 * Handle preflight OPTIONS request.
 * Use at the top of every function:
 *   if (req.method === "OPTIONS") return handleCors();
 */
export function handleCors(): Response {
  return new Response("ok", { headers: corsHeaders });
}

/** Wrap a JSON body with CORS headers */
export function jsonResponse(
  body: unknown,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

/** Error helper with error code */
export function errorResponse(
  code: string,
  message: string,
  status = 400,
): Response {
  return jsonResponse({ success: false, code, error: message }, status);
}
