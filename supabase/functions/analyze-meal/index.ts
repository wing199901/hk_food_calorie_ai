// supabase/functions/analyze-meal/index.ts
// -------------------------------------------------------------
// Core: Receive storage image path -> Call Gemini AI
//       -> Structured JSON output for the mobile app
// -------------------------------------------------------------
// Tech Spec: TypeScript (Deno 2.x) | Timeout 30s | Memory 256MB

import {
  createAdminClient,
  createUserClient,
  requireUserId,
} from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const GEMINI_TIMEOUT_MS = 20_000;
const GEMINI_MAX_RETRIES = 2;
const RETRYABLE_STATUS_CODES = new Set([408, 429, 500, 502, 503, 504]);

const IMAGE_BUCKET = "meal-images";
const MAX_IMAGE_BYTES = 1_500_000;
const SIGNED_URL_EXPIRES_IN_SECONDS = 60 * 60 * 24 * 7;
const ALLOWED_IMAGE_MIME_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
];

let bucketEnsured = false;

// -- System Instruction (behavioural / domain knowledge only) --
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

// -- Response Schema (Gemini Structured Output) ---------------
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

function buildSummaryName(items: FoodItem[]): string {
  if (items.length === 0) return "AI Scanned Meal";

  const firstName =
    items[0].name_en?.trim() || items[0].name_zh?.trim() || "AI Scanned Meal";

  if (items.length === 1) return firstName;
  return `${firstName} + ${items.length - 1} more`;
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

function toOptionalInt(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.round(value);
  }

  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return Math.round(parsed);
    }
  }

  return null;
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

function inferMimeType(imagePath: string): string {
  const normalized = imagePath.toLowerCase();
  if (normalized.endsWith(".png")) return "image/png";
  if (normalized.endsWith(".webp")) return "image/webp";
  if (normalized.endsWith(".heic")) return "image/heic";
  if (normalized.endsWith(".heif")) return "image/heif";
  return "image/jpeg";
}

function normalizeStorageUrl(url: string): string {
  if (url.startsWith("http://") || url.startsWith("https://")) {
    return url;
  }

  const baseUrl = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/+$/, "");
  const normalizedPath = url.startsWith("/") ? url : `/${url}`;
  return `${baseUrl}${normalizedPath}`;
}

async function createSignedImageUrl(
  supabase: ReturnType<typeof createUserClient>,
  imagePath: string,
): Promise<string | null> {
  const { data, error } = await supabase.storage
    .from(IMAGE_BUCKET)
    .createSignedUrl(imagePath, SIGNED_URL_EXPIRES_IN_SECONDS);

  if (error || !data?.signedUrl) {
    console.warn("Failed to create signed image URL:", error?.message);
    return null;
  }

  return normalizeStorageUrl(data.signedUrl);
}

function encodeInlineImageData(bytes: Uint8Array): string {
  const chunkSize = 0x8000;
  let binary = "";

  for (let i = 0; i < bytes.length; i += chunkSize) {
    const chunk = bytes.subarray(i, i + chunkSize);
    binary += String.fromCharCode(...chunk);
  }

  return btoa(binary);
}

async function ensureImageBucket(): Promise<void> {
  if (bucketEnsured) return;

  const admin = createAdminClient();
  const { data: buckets, error: listError } = await admin.storage.listBuckets();

  if (listError) {
    throw new Error(`Failed to list storage buckets: ${listError.message}`);
  }

  const bucketExists = (buckets ?? []).some(
    (bucket: { id?: string; name?: string }) =>
      bucket.id === IMAGE_BUCKET || bucket.name === IMAGE_BUCKET,
  );

  if (!bucketExists) {
    const { error: createError } = await admin.storage.createBucket(
      IMAGE_BUCKET,
      {
        public: false,
        fileSizeLimit: `${MAX_IMAGE_BYTES}`,
        allowedMimeTypes: ALLOWED_IMAGE_MIME_TYPES,
      },
    );

    if (createError) {
      const message = createError.message.toLowerCase();
      if (!message.includes("already exists")) {
        throw new Error(
          `Failed to create storage bucket ${IMAGE_BUCKET}: ${createError.message}`,
        );
      }
    }
  } else {
    const { error: updateError } = await admin.storage.updateBucket(
      IMAGE_BUCKET,
      {
        public: false,
        fileSizeLimit: `${MAX_IMAGE_BYTES}`,
        allowedMimeTypes: ALLOWED_IMAGE_MIME_TYPES,
      },
    );

    if (updateError) {
      throw new Error(
        `Failed to update storage bucket ${IMAGE_BUCKET}: ${updateError.message}`,
      );
    }
  }

  bucketEnsured = true;
}

async function callGeminiWithRetry(
  inlineImageData: string,
  mimeType: string,
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
                    mime_type: mimeType,
                    data: inlineImageData,
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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    const body = await req.json();
    const imagePath =
      typeof body?.image_path === "string" ? body.image_path.trim() : "";
    const mealDate =
      typeof body?.meal_date === "string" && body.meal_date.length > 0
        ? body.meal_date
        : new Date().toISOString().split("T")[0];

    if (!imagePath) {
      return errorResponse("MISSING_IMAGE_PATH", "Missing image_path", 400);
    }

    const supabase = createUserClient(req);
    let user_id: string;
    try {
      user_id = await requireUserId(supabase);
    } catch {
      return errorResponse("UNAUTHORIZED", "Unauthorized", 401);
    }

    if (!imagePath.startsWith(`${user_id}/`)) {
      return errorResponse(
        "FORBIDDEN_IMAGE_PATH",
        "Image path does not belong to the authenticated user",
        403,
      );
    }

    await ensureImageBucket();

    let imageBytes: Uint8Array;
    const mimeType = inferMimeType(imagePath);
    const imageUrl = await createSignedImageUrl(supabase, imagePath);

    const { data: imageBlob, error: downloadError } = await supabase.storage
      .from(IMAGE_BUCKET)
      .download(imagePath);

    if (downloadError || !imageBlob) {
      return errorResponse("IMAGE_NOT_FOUND", "Uploaded image not found", 404);
    }

    imageBytes = new Uint8Array(await imageBlob.arrayBuffer());
    if (imageBytes.byteLength == 0) {
      return errorResponse("IMAGE_EMPTY", "Uploaded image is empty", 400);
    }

    if (imageBytes.byteLength > MAX_IMAGE_BYTES) {
      return errorResponse(
        "IMAGE_TOO_LARGE",
        "Image too large, max 1.5 MB after compression",
        413,
      );
    }

    const inlineImageData = encodeInlineImageData(imageBytes);

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey) {
      return errorResponse(
        "CONFIG_ERROR",
        "GEMINI_API_KEY not configured",
        500,
      );
    }

    let geminiRes: Response;
    const geminiStartedAt = Date.now();
    try {
      geminiRes = await callGeminiWithRetry(
        inlineImageData,
        mimeType,
        geminiKey,
      );
    } catch (err) {
      console.error(
        "Gemini network error:",
        redactSecrets(extractErrorMessage(err)),
      );
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
    const geminiLatencyMs = Math.max(0, Date.now() - geminiStartedAt);
    const usageMetadata = geminiData?.usageMetadata ?? {};
    const inputTokens = toOptionalInt(usageMetadata.promptTokenCount);
    const outputTokens = toOptionalInt(usageMetadata.candidatesTokenCount);
    const totalTokens = toOptionalInt(usageMetadata.totalTokenCount);
    const rawText =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";

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

    if (analysis.error || items.length === 0) {
      return jsonResponse({
        success: false,
        code: "NO_FOOD_DETECTED",
        error: analysis.error ?? "No food or drink detected",
        image_path: imagePath,
        image_url: imageUrl,
        items: [],
      });
    }

    const totalCalories = Math.round(
      (analysis.total_calories ?? 0) > 0
        ? analysis.total_calories
        : items.reduce((sum, item) => sum + (item.calories || 0), 0),
    );
    const totalProtein = Math.round(
      (analysis.total_protein ?? 0) > 0
        ? analysis.total_protein
        : items.reduce((sum, item) => sum + (item.protein || 0), 0),
    );
    const totalCarbs = Math.round(
      (analysis.total_carbs ?? 0) > 0
        ? analysis.total_carbs
        : items.reduce((sum, item) => sum + (item.carbs || 0), 0),
    );
    const totalFat = Math.round(
      (analysis.total_fat ?? 0) > 0
        ? analysis.total_fat
        : items.reduce((sum, item) => sum + (item.fat || 0), 0),
    );
    const totalSugar = Math.round(
      (analysis.total_sugar ?? 0) > 0
        ? analysis.total_sugar
        : items.reduce((sum, item) => sum + (item.sugar || 0), 0),
    );

    const analysisSummaryName = buildSummaryName(items);

    const admin = createAdminClient();

    const { data: analysisRow, error: analysisInsertError } = await admin
      .from("ai_meal_analyses")
      .insert({
        user_id,
        meal_date: mealDate,
        image_path: imagePath,
        image_url: imageUrl,
        ai_summary_name: analysisSummaryName,
        ai_items: items,
        ai_total_calories: totalCalories,
        ai_total_protein: totalProtein,
        ai_total_carbs: totalCarbs,
        ai_total_fat: totalFat,
        ai_total_sugar: totalSugar,
        ai_model: GEMINI_MODEL,
        input_tokens: inputTokens,
        output_tokens: outputTokens,
        total_tokens: totalTokens,
        image_bytes: imageBytes.byteLength,
        latency_ms: geminiLatencyMs,
        feedback_status: "pending",
      })
      .select("id")
      .single();

    if (analysisInsertError || !analysisRow?.id) {
      console.error("Failed to store ai_meal_analyses:", analysisInsertError);
      return errorResponse(
        "ANALYSIS_STORE_ERROR",
        "Failed to store AI analysis result",
        500,
      );
    }

    return jsonResponse({
      success: true,
      analysis_id: analysisRow.id,
      meal_date: mealDate,
      image_path: imagePath,
      image_url: imageUrl,
      items,
      total_calories: totalCalories,
      total_protein: totalProtein,
      total_carbs: totalCarbs,
      total_fat: totalFat,
      total_sugar: totalSugar,
    });
  } catch (err) {
    console.error(
      "analyze-meal error:",
      redactSecrets(extractErrorMessage(err)),
    );
    return errorResponse("INTERNAL_ERROR", "Internal server error", 500);
  }
});
