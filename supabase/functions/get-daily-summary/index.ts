// supabase/functions/get-daily-summary/index.ts
// ─────────────────────────────────────────────
// 拉取指定日期的飲食總結（從 meal_records）
// 包含熱量、營養素、AI 簡單提示
// ─────────────────────────────────────────────

import { createUserClient, requireUserId } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    const { meal_date = new Date().toISOString().split("T")[0] } =
      await req.json();

    const supabase = createUserClient(req);
    let user_id: string;
    try {
      user_id = await requireUserId(supabase);
    } catch (e) {
      return errorResponse("UNAUTHORIZED", "Unauthorized", 401);
    }

    // ── Fetch meal_records (AI 分析) ─────────
    const { data: records, error: recErr } = await supabase
      .from("meal_records")
      .select(
        "id, items, total_calories, total_protein, total_carbs, total_fat, total_sugar, created_at",
      )
      .eq("user_id", user_id)
      .eq("meal_date", meal_date)
      .is("deleted_at", null)
      .order("created_at", { ascending: true });

    if (recErr) {
      console.error("meal_records fetch error:", recErr);
      return errorResponse("DB_QUERY_ERROR", "Failed to fetch records", 500);
    }

    // ── Aggregate from meal_records ──────────
    let totalCalories = 0;
    let totalProtein = 0;
    let totalCarbs = 0;
    let totalFat = 0;
    let totalSugar = 0;
    let itemsCount = 0;

    // deno-lint-ignore no-explicit-any
    const allItems: any[] = [];

    for (const rec of records ?? []) {
      totalCalories += rec.total_calories || 0;
      totalProtein += rec.total_protein || 0;
      totalCarbs += rec.total_carbs || 0;
      totalFat += rec.total_fat || 0;
      totalSugar += rec.total_sugar || 0;
      const items = rec.items as unknown[];
      itemsCount += items?.length ?? 0;
      if (items) allItems.push(...items);
    }

    // ── Fetch calorie target ─────────────────
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("calorie_target")
      .eq("user_id", user_id)
      .maybeSingle();

    const calorieTarget = profile?.calorie_target ?? 2000;
    const remaining = calorieTarget - totalCalories;

    // ── Generate simple AI tip ───────────────
    const aiTip = generateTip({
      totalCalories,
      totalProtein,
      totalCarbs,
      totalFat,
      calorieTarget,
      itemsCount,
    });

    return jsonResponse({
      success: true,
      meal_date,
      total_calories: totalCalories,
      macros: {
        protein: totalProtein,
        carbs: totalCarbs,
        fat: totalFat,
        sugar: totalSugar,
      },
      items_count: itemsCount,
      calorie_target: calorieTarget,
      remaining_calories: remaining,
      items: allItems,
      ai_tip: aiTip,
    });
  } catch (err) {
    console.error("get-daily-summary error:", err);
    return errorResponse("INTERNAL_ERROR", "Internal server error", 500);
  }
});

// ── Simple tip generator (no AI call needed) ──
function generateTip(data: {
  totalCalories: number;
  totalProtein: number;
  totalCarbs: number;
  totalFat: number;
  calorieTarget: number;
  itemsCount: number;
}): string {
  const {
    totalCalories,
    totalProtein,
    totalCarbs,
    totalFat,
    calorieTarget,
    itemsCount,
  } = data;

  if (itemsCount === 0) return "今日未有紀錄，記得影相記錄飲食！📸";

  const pct = Math.round((totalCalories / calorieTarget) * 100);

  const tips: string[] = [];

  if (pct > 110) {
    tips.push(`今日已攝取目標嘅 ${pct}%，超標咗！建議下一餐食清淡啲。`);
  } else if (pct > 90) {
    tips.push(`接近今日目標 (${pct}%)，注意控制份量。`);
  } else if (pct < 50 && itemsCount >= 2) {
    tips.push(`先食咗目標嘅 ${pct}%，仲有空間食多啲健康食物。`);
  }

  // Macro check
  const totalMacrosCal = totalProtein * 4 + totalCarbs * 4 + totalFat * 9;
  if (totalMacrosCal > 0) {
    const proteinPct = Math.round(((totalProtein * 4) / totalMacrosCal) * 100);
    if (proteinPct < 15) {
      tips.push("今日蛋白質偏低，建議加啲雞蛋、雞胸或豆腐。");
    }
    const fatPct = Math.round(((totalFat * 9) / totalMacrosCal) * 100);
    if (fatPct > 40) {
      tips.push("脂肪比例偏高，試下揀蒸或烚嘅煮法。");
    }
  }

  return tips.length > 0
    ? tips.join(" ")
    : `今日攝取 ${totalCalories} kcal，佔目標 ${pct}%，繼續保持！👍`;
}
