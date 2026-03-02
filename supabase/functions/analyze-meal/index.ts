// supabase/functions/analyze-meal/index.ts
// ─────────────────────────────────────────────
// Core: Receive food/drink photo → Call Gemini AI
//       → Parse JSON → Save to meal_records
// ─────────────────────────────────────────────
// Tech Spec: TypeScript (Deno 2.x) | Timeout 30s | Memory 256MB | Max 5MB image

import { createAdminClient } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

// ── Meal analysis prompt (all cuisines, HK-specialised) ──────
const SYSTEM_PROMPT = `你係專業營養師，可以分析任何菜系嘅食物同飲品相片（中式、西式、日韓、東南亞、甜品、飲品等），只返嚴格 JSON（唔好加任何解釋）：
{
  "items": [
    {
      "name_zh": "食物名（繁體中文）",
      "name_en": "English Name",
      "portion_size": 數量(數字，例如 1、2、0.5),
      "portion_unit": "unit in English (e.g. plate, bowl, piece, cup, slice, serving, glass, can, pack)",
      "portion_grams": 固體食物估計克數(g)，飲品填 null,
      "portion_ml": 飲品估計毫升(ml)，固體食物填 null,
      "calories": 熱量(kcal),
      "protein": 蛋白質(g),
      "carbs": 碳水化合物(g),
      "fat": 脂肪(g),
      "sugar": 糖(g),
      "confidence": 0.0到1.0
    }
  ],
  "total_calories": 總熱量,
  "total_protein": 總蛋白質,
  "total_carbs": 總碳水,
  "total_fat": 總脂肪
}

特別注意：
- 支援所有菜系：西餐（牛排、漢堡、意粉、沙律等）、日韓（拉麵、壽司、炸雞等）、東南亞（泰式、越式等）、中式、港式等
- 特別熟悉香港本地食物：茶餐廳、大排檔、酒樓點心、街頭小食、便利店食品
- 常見香港菜要認準：燒賣、腸粉、奶茶、豬扒飯、菠蘿包、蛋撻、雲吞麵、煲仔飯等
- 飲品都要分析（奶茶、咖啡、汽水、果汁、啤酒、湯等），用 portion_ml 記錄容量
- 固體食物用 portion_grams，飲品用 portion_ml，唔好兩個都填
- 份量要估計相片中嘅真實份量，唔好假設標準份量
- 如遇唔確定嘅食物，畀出最合理嘅估計同較低嘅 confidence

如果相片冇食物或睇唔清楚，回覆：
{ "items": [], "error": "No food or drink detected" }`;

// ── Types ────────────────────────────────────────────────────
interface FoodItem {
  name_zh: string;
  name_en: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  portion_size: number;
  portion_unit: string;
  portion_grams?: number | null;
  portion_ml?: number | null;
  confidence: number;
}

interface AnalysisResult {
  items: FoodItem[];
  total_calories?: number;
  total_protein?: number;
  total_carbs?: number;
  total_fat?: number;
  error?: string;
}

// ── Main handler ─────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    // ── Parse body ────────────────────────────
    const {
      image_base64,
      user_id,
      date = new Date().toISOString().split("T")[0],
    } = await req.json();

    if (!image_base64)
      return errorResponse("MISSING_IMAGE", "Missing image_base64");
    if (!user_id) return errorResponse("MISSING_USER_ID", "Missing user_id");

    // Validate image size (~5 MB after base64 ≈ ~6.67 MB string)
    if (image_base64.length > 7_000_000) {
      return errorResponse(
        "IMAGE_TOO_LARGE",
        "Image too large, max 5 MB after compression",
        413,
      );
    }

    // ── Call Gemini API ───────────────────────
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey)
      return errorResponse(
        "CONFIG_ERROR",
        "GEMINI_API_KEY not configured",
        500,
      );

    const geminiRes = await fetch(`${GEMINI_URL}?key=${geminiKey}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: SYSTEM_PROMPT },
              {
                inline_data: {
                  mime_type: "image/jpeg",
                  data: image_base64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 2048,
        },
      }),
    });

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      console.error("Gemini API error:", errText);
      return errorResponse(
        "AI_ERROR",
        `Gemini API error: ${geminiRes.status}`,
        502,
      );
    }

    const geminiData = await geminiRes.json();
    const rawText =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";

    // ── Parse AI response (strip markdown fences if present) ──
    const cleanedText = rawText.replace(/```json|```/g, "").trim();

    let analysis: AnalysisResult;
    try {
      analysis = JSON.parse(cleanedText);
    } catch {
      console.error("Failed to parse Gemini response:", rawText);
      return errorResponse(
        "AI_PARSE_ERROR",
        "AI response format error, please retake photo",
        502,
      );
    }

    const items: FoodItem[] = analysis.items ?? [];

    // ── Handle AI error (e.g. no food detected) ─────────────
    if (analysis.error || items.length === 0) {
      return jsonResponse({
        success: false,
        code: "NO_FOOD_DETECTED",
        error: analysis.error ?? "No food or drink detected",
        items: [],
      });
    }

    // ── Calculate totals (prefer AI totals, fallback to sum) ──
    // Math.round() — DB columns are integer, Gemini may return decimals
    const totalCalories = Math.round(
      analysis.total_calories ??
        items.reduce((s, i) => s + (i.calories || 0), 0),
    );
    const totalProtein = Math.round(
      analysis.total_protein ?? items.reduce((s, i) => s + (i.protein || 0), 0),
    );
    const totalCarbs = Math.round(
      analysis.total_carbs ?? items.reduce((s, i) => s + (i.carbs || 0), 0),
    );
    const totalFat = Math.round(
      analysis.total_fat ?? items.reduce((s, i) => s + (i.fat || 0), 0),
    );

    // ── Insert into meal_records (service role, bypasses RLS) ─
    const supabase = createAdminClient();

    const { data: record, error: insertErr } = await supabase
      .from("meal_records")
      .insert({
        id: crypto.randomUUID(),
        user_id,
        date,
        items,
        total_calories: totalCalories,
        total_protein: totalProtein,
        total_carbs: totalCarbs,
        total_fat: totalFat,
      })
      .select()
      .single();

    if (insertErr) {
      console.error("DB insert error:", insertErr);
      return errorResponse("DB_INSERT_ERROR", "Failed to save record", 500);
    }

    return jsonResponse({
      success: true,
      record_id: record.id,
      items,
      total_calories: totalCalories,
      total_protein: totalProtein,
      total_carbs: totalCarbs,
      total_fat: totalFat,
    });
  } catch (err) {
    console.error("analyze-meal error:", err);
    return errorResponse(
      "INTERNAL_ERROR",
      err instanceof Error ? err.message : "Internal error",
      400,
    );
  }
});
