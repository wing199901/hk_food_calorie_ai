// supabase/functions/generate-ai-insight/index.ts
// ─────────────────────────────────────────────
// V2: AI 生成每週/每月飲食報告 + 個人化建議
// 例如「你連續3日熱量過高」「蛋白質持續不足」
// ─────────────────────────────────────────────

import { createAdminClient } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    const { user_id, period } = await req.json();

    if (!user_id) return errorResponse("MISSING_USER_ID", "Missing user_id");
    if (!period || !["week", "month"].includes(period)) {
      return errorResponse("INVALID_PARAM", "period must be 'week' or 'month'");
    }

    const supabase = createAdminClient();

    // ── Calculate date range ─────────────────
    const now = new Date();
    const daysBack = period === "week" ? 7 : 30;
    const startDate = new Date(now);
    startDate.setDate(startDate.getDate() - daysBack);
    const startStr = startDate.toISOString().slice(0, 10);
    const endStr = now.toISOString().slice(0, 10);

    // ── Fetch meal_records in range ──────────
    const { data: records, error: recErr } = await supabase
      .from("meal_records")
      .select(
        "date, items, total_calories, total_protein, total_carbs, total_fat, total_sugar",
      )
      .eq("user_id", user_id)
      .gte("date", startStr)
      .lte("date", endStr)
      .is("deleted_at", null)
      .order("date", { ascending: true });

    if (recErr) {
      console.error("Fetch records error:", recErr);
      return errorResponse("DB_QUERY_ERROR", "Failed to fetch records", 500);
    }

    // ── Fetch user profile ───────────────────
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("age, weight, height, gender, activity_level, calorie_target")
      .eq("user_id", user_id)
      .maybeSingle();

    const calorieTarget = profile?.calorie_target ?? 2000;

    // ── Build daily aggregation for charts ───
    const dailyMap = new Map<
      string,
      { calories: number; protein: number; carbs: number; fat: number; sugar: number }
    >();

    for (const rec of records ?? []) {
      const day = dailyMap.get(rec.date) ?? {
        calories: 0,
        protein: 0,
        carbs: 0,
        fat: 0,
        sugar: 0,
      };
      day.calories += rec.total_calories || 0;
      day.protein += rec.total_protein || 0;
      day.carbs += rec.total_carbs || 0;
      day.fat += rec.total_fat || 0;
      day.sugar += rec.total_sugar || 0;
      dailyMap.set(rec.date, day);
    }

    const chartsData = Array.from(dailyMap.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, data]) => ({ date, ...data }));

    // ── Call Gemini for insight ───────────────
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey)
      return errorResponse(
        "CONFIG_ERROR",
        "GEMINI_API_KEY not configured",
        500,
      );

    const summaryForAI = JSON.stringify({
      period,
      calorie_target: calorieTarget,
      user_profile: profile
        ? {
            age: profile.age,
            weight: profile.weight,
            height: profile.height,
            gender: profile.gender,
            activity_level: profile.activity_level,
          }
        : null,
      daily_data: chartsData,
      total_days_tracked: chartsData.length,
    });

    const insightPrompt = `你係一個香港營養師 AI，以下係用戶過去${
      period === "week" ? "一星期" : "一個月"
    }嘅飲食數據。

請用繁體中文生成一份簡潔嘅飲食報告，包括：
1. 總結（平均每日卡路里、同目標比較）
2. 營養素分析（蛋白質/碳水/脂肪比例是否合理）
3. 趨勢觀察（例如連續幾日超標、週末飲食模式等）
4. 2-3 條具體建議（針對香港飲食習慣）

數據：
${summaryForAI}

回覆格式為純文字，可以用 emoji 同分段，唔需要 JSON。`;

    const geminiRes = await fetch(`${GEMINI_URL}?key=${geminiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: insightPrompt }] }],
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 4096,
        },
      }),
    });

    let reportText = "";
    if (geminiRes.ok) {
      const geminiData = await geminiRes.json();
      reportText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
    } else {
      console.error("Gemini insight error:", await geminiRes.text());
      reportText = "未能生成 AI 分析報告，請稍後再試。";
    }

    return jsonResponse({
      success: true,
      period,
      date_range: { from: startStr, to: endStr },
      report_text: reportText,
      charts_data: chartsData,
      summary: {
        total_days: chartsData.length,
        avg_calories:
          chartsData.length > 0
            ? Math.round(
                chartsData.reduce((s, d) => s + d.calories, 0) /
                  chartsData.length,
              )
            : 0,
        calorie_target: calorieTarget,
      },
    });
  } catch (err) {
    console.error("generate-ai-insight error:", err);
    return errorResponse(
      "INTERNAL_ERROR",
      "Internal server error",
      500,
    );
  }
});
