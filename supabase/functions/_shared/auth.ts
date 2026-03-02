import { createClient, SupabaseClient } from "@supabase/supabase-js";

/**
 * Create a Supabase client scoped to the calling user's JWT.
 * This respects RLS policies automatically.
 */
export function createUserClient(req: Request): SupabaseClient {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) throw new Error("Missing Authorization header");

  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    },
  );
}

/**
 * Create an admin (service-role) Supabase client that bypasses RLS.
 * Only use for cron / admin operations.
 */
export function createAdminClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

/**
 * Extract the authenticated user's ID from the JWT via Supabase.
 * Returns userId string or throws.
 */
export async function requireUserId(
  supabase: SupabaseClient,
): Promise<string> {
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();
  if (error || !user) throw new Error("Unauthorized");
  return user.id;
}
