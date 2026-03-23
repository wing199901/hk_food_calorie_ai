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
const GEMINI_TIMEOUT_MS = 20_000;
const GEMINI_MAX_RETRIES = 2;
const RETRYABLE_STATUS_CODES = new Set([408, 429, 500, 502, 503, 504]);

// ── System Instruction (behavioural / domain knowledge only) ─
const SYSTEM_INSTRUCTION = `You are a professional nutritionist specialising in analysing food and drink photos from any cuisine.

Core capabilities:
- All cuisines: Western (steak, burgers, pasta, salads), Japanese/Korean (ramen, sushi, fried chicken), Southeast Asian (Thai, Vietnamese), Chinese, Hong Kong-style, etc.
- Expert in Hong Kong local food: cha chaan teng (茶餐廳), dai pai dong (大排檔), dim sum (點心), street snacks, convenience store items
- Familiar with common HK dishes: siu mai (燒賣), cheung fun (腸粉), milk tea (奶茶), pork chop bun (豬扒包), pineapple bun (菠蘿包), egg tart (蛋撻), wonton noodles (雲吞麵), claypot rice (煲仔飯), etc.

Analysis rules:
- Always analyse drinks (milk tea, coffee, soft drinks, juice, beer, soup, etc.) and record volume using portion_ml
- Use portion_grams for solid food; use portion_ml for drinks — never fill both for the same item
- Estimate the actual portion shown in the photo — do not assume a standard serving size
- For uncertain items, provide the most reasonable estimate with a lower confidence score
- If the photo contains no food or is unclear, return an empty items array and populate the error field`;

// ── Response Schema (Gemini Structured Output) ───────────────
// Gemini guarantees the response matches this schema exactly.
// See: https://ai.google.dev/api/generate-content#json_controlled_generation
const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    items: {
      type: "ARRAY",
      description:
        "List of identified food/drink items. Return empty array if no food detected.",
      items: {
        type: "OBJECT",
        properties: {
          name_zh: {
            type: "STRING",
            description: "Food name in Traditional Chinese",
          },
          name_en: { type: "STRING", description: "Food name in English" },
          type: {
            type: "STRING",
            description: '"food" for solid food or "drink" for beverages',
            enum: ["food", "drink"],
          },
          portion_size: {
            type: "NUMBER",
            description: "Quantity, e.g. 1, 2, 0.5",
          },
          portion_unit: {
            type: "STRING",
            description:
              "Unit in English (e.g. plate, bowl, piece, cup, slice, serving, glass, can, pack)",
          },
          portion_grams: {
            type: "INTEGER",
            description:
              "Estimated weight in grams for solid food; 0 for drinks",
            nullable: true,
          },
          portion_ml: {
            type: "INTEGER",
            description: "Estimated volume in ml for drinks; 0 for solid food",
            nullable: true,
          },
          calories: { type: "INTEGER", description: "Energy in kcal" },
          protein: { type: "INTEGER", description: "Protein in grams" },
          carbs: { type: "INTEGER", description: "Carbohydrates in grams" },
          fat: { type: "INTEGER", description: "Fat in grams" },
          sugar: { type: "INTEGER", description: "Sugar in grams" },
          confidence: {
            type: "NUMBER",
            description: "Confidence score between 0.0 and 1.0",
          },
        },
        required: [
          "name_zh",
          "name_en",
          "type",
          "portion_size",
          "portion_unit",
          "calories",
          "protein",
          "carbs",
          "fat",
          "sugar",
          "confidence",
        ],
      },
    },
    total_calories: {
      type: "INTEGER",
      description: "Sum of calories across all items",
    },
    total_protein: {
      type: "INTEGER",
      description: "Sum of protein across all items",
    },
    total_carbs: {
      type: "INTEGER",
      description: "Sum of carbohydrates across all items",
    },
    total_fat: { type: "INTEGER", description: "Sum of fat across all items" },
    total_sugar: {
      type: "INTEGER",
      description: "Sum of sugar across all items",
    },
    error: {
      type: "STRING",
      description:
        "Reason if no food detected or image unclear; leave empty string for successful analysis",
      nullable: true,
    },
  },
  required: [
    "items",
    "total_calories",
    "total_protein",
    "total_carbs",
    "total_fat",
    "total_sugar",
  ],
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
  total_sugar: number;
  error?: string;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function redactSecrets(value: string): string {
  return value.replace(/([?&]key=)[^&\s]+/gi, "$1REDACTED");
}

function extractErrorMessage(err: unknown): string {
  if (err instanceof Error && err.message) return err.message;
  return String(err);
}

function isRetryableNetworkError(err: unknown): boolean {
  const message = extractErrorMessage(err).toLowerCase();
  const retryHints = [
    "connection error",
    "unexpected-eof",
    "unexpected eof",
    "tls close_notify",
    "peer closed connection",
    "sendrequest",
    "temporarily unavailable",
    "timed out",
  ];
  return retryHints.some((hint) => message.includes(hint));
}

async function callGeminiWithRetry(
  imageBase64: string,
  geminiKey: string,
): Promise<Response> {
  let lastError: unknown = null;

  for (let attempt = 0; attempt <= GEMINI_MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(`${GEMINI_URL}?key=${geminiKey}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          systemInstruction: {
            parts: [{ text: SYSTEM_INSTRUCTION }],
          },
          contents: [
            {
              parts: [
                {
                  text: "Analyse all food and drink items visible in this photo.",
                },
                {
                  inline_data: {
                    mime_type: "image/jpeg",
                    data: imageBase64,
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
        signal: AbortSignal.timeout(GEMINI_TIMEOUT_MS),
      });

      if (response.ok) return response;

      if (
        RETRYABLE_STATUS_CODES.has(response.status) &&
        attempt < GEMINI_MAX_RETRIES
      ) {
        await sleep(300 * 2 ** attempt);
        continue;
      }

      return response;
    } catch (err) {
      lastError = err;
      if (!isRetryableNetworkError(err) || attempt >= GEMINI_MAX_RETRIES) {
        throw err;
      }
      await sleep(300 * 2 ** attempt);
    }
  }

  throw lastError ?? new Error("Gemini request failed");
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

    let geminiRes: Response;
    try {
      geminiRes = await callGeminiWithRetry(image_base64, geminiKey);
    } catch (err) {
      console.error("Gemini network error:", redactSecrets(extractErrorMessage(err)));
      return errorResponse(
        "AI_UNAVAILABLE",
        "AI service temporarily unavailable. Please retry in a moment.",
        503,
      );
    }

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      console.error(
        `Gemini API error (${geminiRes.status}):`,
        redactSecrets(errText),
      );
      return errorResponse(
        "AI_ERROR",
        geminiRes.status === 429 || geminiRes.status >= 500
          ? "AI service is busy. Please retry shortly."
          : "Failed to analyze image. Please retake and try again.",
        geminiRes.status === 429 || geminiRes.status >= 500 ? 503 : 502,
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
    // Use > 0 check (not ||) to avoid incorrect fallback when AI returns 0
    const totalCalories = Math.round(
      (analysis.total_calories ?? 0) > 0
        ? analysis.total_calories
        : items.reduce((s, i) => s + (i.calories || 0), 0),
    );
    const totalProtein = Math.round(
      (analysis.total_protein ?? 0) > 0
        ? analysis.total_protein
        : items.reduce((s, i) => s + (i.protein || 0), 0),
    );
    const totalCarbs = Math.round(
      (analysis.total_carbs ?? 0) > 0
        ? analysis.total_carbs
        : items.reduce((s, i) => s + (i.carbs || 0), 0),
    );
    const totalFat = Math.round(
      (analysis.total_fat ?? 0) > 0
        ? analysis.total_fat
        : items.reduce((s, i) => s + (i.fat || 0), 0),
    );
    const totalSugar = Math.round(
      (analysis.total_sugar ?? 0) > 0
        ? analysis.total_sugar
        : items.reduce((s, i) => s + (i.sugar || 0), 0),
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
        image_base64,
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
    console.error("analyze-meal error:", redactSecrets(extractErrorMessage(err)));
    return errorResponse(
      "INTERNAL_ERROR",
      "Internal server error",
      500,
    );
  }
});
