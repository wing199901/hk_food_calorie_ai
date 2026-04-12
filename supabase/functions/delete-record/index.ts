import { createUserClient, requireUserId } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    const { record_id, meal_date, hard_delete = false } = await req.json();

    if (!record_id && !meal_date) {
      return errorResponse(
        "INVALID_PARAM",
        "Must provide either record_id or meal_date",
      );
    }

    const supabase = createUserClient(req);
    let user_id: string;
    try {
      user_id = await requireUserId(supabase);
    } catch (e) {
      return errorResponse("UNAUTHORIZED", "Unauthorized", 401);
    }

    if (hard_delete) {
      if (record_id) {
        const { error } = await supabase
          .from("meal_records")
          .delete()
          .eq("id", record_id)
          .eq("user_id", user_id);
        if (error) return errorResponse("DELETE_FAILED", error.message, 500);
      } else {
        const { error } = await supabase
          .from("meal_records")
          .delete()
          .eq("meal_date", meal_date)
          .eq("user_id", user_id);
        if (error) return errorResponse("DELETE_FAILED", error.message, 500);
      }
      return jsonResponse({
        success: true,
        message: "Record(s) permanently deleted",
      });
    } else {
      const now = new Date().toISOString();
      if (record_id) {
        const { error } = await supabase
          .from("meal_records")
          .update({ deleted_at: now })
          .eq("id", record_id)
          .eq("user_id", user_id);
        if (error)
          return errorResponse("SOFT_DELETE_FAILED", error.message, 500);
      } else {
        const { error } = await supabase
          .from("meal_records")
          .update({ deleted_at: now })
          .eq("meal_date", meal_date)
          .eq("user_id", user_id);
        if (error)
          return errorResponse("SOFT_DELETE_FAILED", error.message, 500);
      }
      return jsonResponse({ success: true, message: "Record(s) soft-deleted" });
    }
  } catch (err) {
    console.error("delete-record error:", err);
    return errorResponse("INTERNAL_ERROR", "Internal server error", 500);
  }
});
