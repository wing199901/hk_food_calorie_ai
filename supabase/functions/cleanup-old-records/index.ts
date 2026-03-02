// supabase/functions/cleanup-old-records/index.ts
// ─────────────────────────────────────────────
// 維護用 Cron Job：自動清理舊紀錄
// 預設清理 365 日以上已 soft-delete 的記錄
// 可由 Supabase Cron 或手動觸發（admin only）
// ─────────────────────────────────────────────
// Supabase Cron 設定（Dashboard → Database → Extensions → pg_cron）:
//   select cron.schedule(
//     'cleanup-old-records',
//     '0 3 * * 0',  -- 每週日凌晨 3 點
//     $$
//     select net.http_post(
//       url := 'https://<project>.supabase.co/functions/v1/cleanup-old-records',
//       headers := '{"Authorization": "Bearer <service_role_key>", "Content-Type": "application/json"}'::jsonb,
//       body := '{"days_old": 365}'::jsonb
//     );
//     $$
//   );
// ─────────────────────────────────────────────

import { createAdminClient } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    // ── Admin-only: verify service role key ──
    const authHeader = req.headers.get("Authorization") ?? "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    // Accept either service_role key as Bearer token, or a valid JWT from an admin
    const token = authHeader.replace("Bearer ", "");
    if (token !== serviceRoleKey) {
      return errorResponse("FORBIDDEN", "Admin access required", 403);
    }

    const { days_old } = (await req.json()) as { days_old?: number };
    const cutoffDays = days_old ?? 365;

    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - cutoffDays);
    const cutoffStr = cutoffDate.toISOString();

    const supabase = createAdminClient();

    // ── Delete soft-deleted records older than cutoff ──
    const { data: softDeleted, error: softErr } = await supabase
      .from("meal_records")
      .delete()
      .not("deleted_at", "is", null)
      .lt("deleted_at", cutoffStr)
      .select("id");

    if (softErr) {
      console.error("Soft-delete cleanup error:", softErr);
    }

    // ── Optionally: delete very old records (even active ones) ──
    // Only if days_old is explicitly > 365
    let ancientDeleted = 0;
    if (cutoffDays >= 730) {
      const ancientDate = new Date();
      ancientDate.setDate(ancientDate.getDate() - cutoffDays);
      const ancientStr = ancientDate.toISOString().slice(0, 10);

      const { data: ancient, error: ancientErr } = await supabase
        .from("meal_records")
        .delete()
        .lt("date", ancientStr)
        .select("id");

      if (ancientErr) {
        console.error("Ancient cleanup error:", ancientErr);
      }
      ancientDeleted = ancient?.length ?? 0;
    }

    const totalDeleted = (softDeleted?.length ?? 0) + ancientDeleted;

    console.log(
      `Cleanup completed: ${totalDeleted} records deleted (soft: ${softDeleted?.length ?? 0}, ancient: ${ancientDeleted})`,
    );

    return jsonResponse({
      success: true,
      deleted: totalDeleted,
      soft_deleted_cleaned: softDeleted?.length ?? 0,
      ancient_cleaned: ancientDeleted,
      cutoff_days: cutoffDays,
    });
  } catch (err) {
    console.error("cleanup-old-records error:", err);
    return errorResponse(
      "INTERNAL_ERROR",
      err instanceof Error ? err.message : "Internal error",
      500,
    );
  }
});
