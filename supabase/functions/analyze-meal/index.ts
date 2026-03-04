// supabase/functions/analyze-meal/index.ts
// ─────────────────────────────────────────────
// Core: Receive food/drink photo → Call Gemini AI
//       → Structured JSON output → Save to meal_records
// ─────────────────────────────────────────────
// Tech Spec: TypeScript (Deno 2.x) | Timeout 30s | Memory 256MB | Max 5MB image
// Uses Gemini Structured Output (responseSchema) for guaranteed valid JSON.

import { createAdminClient } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

// ── System Instruction (behavioural / domain knowledge only) ─
const SYSTEM_INSTRUCTION = `你係專業營養師，負責分析任何菜系嘅食物同飲品相片。

核心能力：
- 支援所有菜系：西餐（牛排、漢堡、意粉、沙律等）、日韓（拉麵、壽司、炸雞等）、東南亞（泰式、越式等）、中式、港式等
- 特別熟悉香港本地食物：茶餐廳、大排檔、酒樓點心、街頭小食、便利店食品
- 常見香港菜要認準：燒賣、腸粉、奶茶、豬扒飯、菠蘿包、蛋撻、雲吞麵、煲仔飯等

分析規則：
- 飲品都要分析（奶茶、咖啡、汽水、果汁、啤酒、湯等），用 portion_ml 記錄容量
- 固體食物用 portion_grams，飲品用 portion_ml，唔好兩個都填
- 份量要估計相片中嘅真實份量，唔好假設標準份量
- 如遇唔確定嘅食物，畀出最合理嘅估計同較低嘅 confidence
- 如果相片冇食物或睇唔清楚，回傳空 items 陣列同 error 訊息`;

// ── Response Schema (Gemini Structured Output) ───────────────
// Gemini guarantees the response matches this schema exactly.
// See: https://ai.google.dev/api/generate-content#json_controlled_generation
const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    items: {
      type: "ARRAY",
      description: "分析到嘅食物/飲品列表，冇食物時回傳空陣列",
      items: {
        type: "OBJECT",
        properties: {
          name_zh:       { type: "STRING",  description: "食物名（繁體中文）" },
          name_en:       { type: "STRING",  description: "English name" },
          type:          { type: "STRING",  description: "food 或 drink", enum: ["food", "drink"] },
          portion_size:  { type: "NUMBER",  description: "數量，例如 1、2、0.5" },
          portion_unit:  { type: "STRING",  description: "Unit in English (e.g. plate, bowl, piece, cup, slice, serving, glass, can, pack)" },
          portion_grams: { type: "INTEGER", description: "固體食物估計克數(g)，飲品填 0", nullable: true },
          portion_ml:    { type: "INTEGER", description: "飲品估計毫升(ml)，固體食物填 0", nullable: true },
          calories:      { type: "INTEGER", description: "熱量 kcal" },
          protein:       { type: "INTEGER", description: "蛋白質 g" },
          carbs:         { type: "INTEGER", description: "碳水化合物 g" },
          fat:           { type: "INTEGER", description: "脂肪 g" },
          sugar:         { type: "INTEGER", description: "糖 g" },
          confidence:    { type: "NUMBER",  description: "0.0 到 1.0 之間" },
        },
        required: [
          "name_zh", "name_en", "type",
          "portion_size", "portion_unit",
          "calories", "protein", "carbs", "fat", "sugar", "confidence",
        ],
      },
    },
    total_calories: { type: "INTEGER", description: "所有 items 總熱量" },
    total_protein:  { type: "INTEGER", description: "所有 items 總蛋白質" },
    total_carbs:    { type: "INTEGER", description: "所有 items 總碳水" },
    total_fat:      { type: "INTEGER", description: "所有 items 總脂肪" },
    error:          { type: "STRING",  description: "冇食物或睇唔清時填寫原因，正常分析時留空字串", nullable: true },
  },
  required: ["items", "total_calories", "total_protein", "total_carbs", "total_fat"],
};

// ── Types ────────────────────────────────────────────────────
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

interface AnalysisResult {
  items: FoodItem[];
  total_calories: number;
  total_protein: number;
  total_carbs: number;
  total_fat: number;
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

    // ── Call Gemini API (Structured Output) ───
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
        systemInstruction: {
          parts: [{ text: SYSTEM_INSTRUCTION }],
        },
        contents: [
          {
            parts: [
              { text: "分析呢張相入面嘅所有食物同飲品。" },
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
          responseMimeType: "application/json",
          responseSchema: RESPONSE_SCHEMA,
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

    // Structured Output guarantees valid JSON — no markdown fence stripping needed
    let analysis: AnalysisResult;
    try {
      analysis = JSON.parse(rawText);
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
    // Schema guarantees total_* fields, but fallback to sum for safety
    const totalCalories = Math.round(
      analysis.total_calories ||
        items.reduce((s, i) => s + (i.calories || 0), 0),
    );
    const totalProtein = Math.round(
      analysis.total_protein || items.reduce((s, i) => s + (i.protein || 0), 0),
    );
    const totalCarbs = Math.round(
      analysis.total_carbs || items.reduce((s, i) => s + (i.carbs || 0), 0),
    );
    const totalFat = Math.round(
      analysis.total_fat || items.reduce((s, i) => s + (i.fat || 0), 0),
    );
    const totalSugar = Math.round(
      items.reduce((s, i) => s + (i.sugar || 0), 0),
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
        total_sugar: totalSugar,
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
      total_sugar: totalSugar,
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
