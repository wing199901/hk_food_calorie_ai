// supabase/functions/update-record/index.ts
// ─────────────────────────────────────────────
// 用戶修改份量後，server-side 更新紀錄
// 重新計算 totals，防止 client 繞過驗證
// ─────────────────────────────────────────────

import { createAdminClient } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

interface FoodItem {
  name_zh: string;
  name_en: string;
  type: "food" | "drink";
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  sugar: number;
  portion_size: number;
  portion_unit: string;
  portion_grams?: number | null;
  portion_ml?: number | null;
  confidence: number;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    const { record_id, user_id, updated_items } = await req.json();

    if (!record_id) return errorResponse("MISSING_PARAM", "Missing record_id");
    if (!user_id) return errorResponse("MISSING_USER_ID", "Missing user_id");
    if (!updated_items || !Array.isArray(updated_items)) {
      return errorResponse("INVALID_PARAM", "updated_items must be an array");
    }

    const supabase = createAdminClient();

    // ── Verify record belongs to user ────────
    const { data: existing, error: fetchErr } = await supabase
      .from("meal_records")
      .select("id, user_id")
      .eq("id", record_id)
      .is("deleted_at", null)
      .single();

    if (fetchErr || !existing) {
      return errorResponse("RECORD_NOT_FOUND", "Record not found", 404);
    }
    if (existing.user_id !== user_id) {
      return errorResponse(
        "UNAUTHORIZED",
        "Not authorized to access this record",
        403,
      );
    }

    // ── Recalculate totals server-side ───────
    const totalCalories = Math.round(
      updated_items.reduce(
        (s: number, i: FoodItem) => s + (i.calories || 0),
        0,
      ),
    );
    const totalProtein = Math.round(
      updated_items.reduce((s: number, i: FoodItem) => s + (i.protein || 0), 0),
    );
    const totalCarbs = Math.round(
      updated_items.reduce((s: number, i: FoodItem) => s + (i.carbs || 0), 0),
    );
    const totalFat = Math.round(
      updated_items.reduce((s: number, i: FoodItem) => s + (i.fat || 0), 0),
    );
    const totalSugar = Math.round(
      updated_items.reduce((s: number, i: FoodItem) => s + (i.sugar || 0), 0),
    );

    // ── Update record ────────────────────────
    const { error: updateErr } = await supabase
      .from("meal_records")
      .update({
        items: updated_items,
        total_calories: totalCalories,
        total_protein: totalProtein,
        total_carbs: totalCarbs,
        total_fat: totalFat,
        total_sugar: totalSugar,
      })
      .eq("id", record_id);

    if (updateErr) {
      console.error("DB update error:", updateErr);
      return errorResponse("DB_UPDATE_ERROR", "Failed to update record", 500);
    }

    return jsonResponse({
      success: true,
      record_id,
      new_totals: {
        total_calories: totalCalories,
        total_protein: totalProtein,
        total_carbs: totalCarbs,
        total_fat: totalFat,
        total_sugar: totalSugar,
      },
    });
  } catch (err) {
    console.error("update-record error:", err);
    return errorResponse(
      "INTERNAL_ERROR",
      err instanceof Error ? err.message : "Internal error",
      400,
    );
  }
});
