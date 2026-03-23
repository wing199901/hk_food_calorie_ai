// supabase/functions/delete-record/index.ts
// ─────────────────────────────────────────────
// 刪除單條或整日 meal_records
// 支援軟刪除（設 deleted_at）
// ─────────────────────────────────────────────

import { createAdminClient } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    const { user_id, record_id, date, hard_delete = false } = await req.json();

    if (!user_id) return errorResponse("MISSING_USER_ID", "Missing user_id");
    if (!record_id && !date) {
      return errorResponse("MISSING_PARAM", "Must provide record_id or date");
    }

    const supabase = createAdminClient();
    let deletedCount = 0;

    if (hard_delete) {
      // ── Hard delete ────────────────────────
      if (record_id) {
        const { data, error } = await supabase
          .from("meal_records")
          .delete()
          .eq("id", record_id)
          .eq("user_id", user_id)
          .select("id");

        if (error) {
          console.error("Hard delete error:", error);
          return errorResponse(
            "DB_DELETE_ERROR",
            "Failed to delete record",
            500,
          );
        }
        deletedCount = data?.length ?? 0;
      } else if (date) {
        const { data, error } = await supabase
          .from("meal_records")
          .delete()
          .eq("user_id", user_id)
          .eq("date", date)
          .select("id");

        if (error) {
          console.error("Hard delete by date error:", error);
          return errorResponse(
            "DB_DELETE_ERROR",
            "Failed to delete records by date",
            500,
          );
        }
        deletedCount = data?.length ?? 0;
      }
    } else {
      // ── Soft delete (set deleted_at) ───────
      const now = new Date().toISOString();

      if (record_id) {
        const { data, error } = await supabase
          .from("meal_records")
          .update({ deleted_at: now })
          .eq("id", record_id)
          .eq("user_id", user_id)
          .is("deleted_at", null)
          .select("id");

        if (error) {
          console.error("Soft delete error:", error);
          return errorResponse(
            "DB_DELETE_ERROR",
            "Failed to soft-delete record",
            500,
          );
        }
        deletedCount = data?.length ?? 0;
      } else if (date) {
        const { data, error } = await supabase
          .from("meal_records")
          .update({ deleted_at: now })
          .eq("user_id", user_id)
          .eq("date", date)
          .is("deleted_at", null)
          .select("id");

        if (error) {
          console.error("Soft delete by date error:", error);
          return errorResponse(
            "DB_DELETE_ERROR",
            "Failed to soft-delete records by date",
            500,
          );
        }
        deletedCount = data?.length ?? 0;
      }
    }

    return jsonResponse({
      success: true,
      deleted_count: deletedCount,
      mode: hard_delete ? "hard" : "soft",
    });
  } catch (err) {
    console.error("delete-record error:", err);
    return errorResponse(
      "INTERNAL_ERROR",
      "Internal server error",
      500,
    );
  }
});
