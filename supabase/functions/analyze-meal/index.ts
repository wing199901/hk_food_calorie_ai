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
import { errorResponse, handleCors, jsonResponse } from "../_shared/cors.ts";

const GEMINI_PRIMARY_MODEL = "gemini-2.5-flash";
const GEMINI_FALLBACK_MODEL = "gemini-3-flash-preview";
const DEFAULT_GEMINI_API_VERSION = "v1beta";
const GEMINI_MODELS = Array.from(
  new Set([GEMINI_PRIMARY_MODEL, GEMINI_FALLBACK_MODEL].filter(Boolean)),
);

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
- Return output using this JSON contract: ingredients[] + total_* fields
- For each ingredient include: name, grams, ml, calories, fat, carb, protein, sugar, confidence
- For solid food: fill grams, set ml to null
- For liquids/drinks: fill ml, set grams to null
- Never fill both grams and ml for the same ingredient
- Estimate the actual portion shown in the photo — do not assume a standard serving size
- For uncertain items, provide the most reasonable estimate with a lower confidence score
- If the photo contains no food or is unclear, return an empty ingredients array and populate the error field`;

// -- Response Schema (Gemini Structured Output) ---------------
const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    ingredients: {
      type: "ARRAY",
      description:
        "List of identified ingredients. Return empty array if no food detected.",
      items: {
        type: "OBJECT",
        properties: {
          name: {
            type: "STRING",
            description: "Ingredient name in English",
          },
          grams: {
            type: "NUMBER",
            description:
              "Estimated mass in grams for solid food; null for liquids",
            nullable: true,
          },
          ml: {
            type: "NUMBER",
            description:
              "Estimated volume in ml for liquids; null for solid food",
            nullable: true,
          },
          calories: { type: "NUMBER", description: "Energy in kcal" },
          fat: { type: "NUMBER", description: "Fat in grams" },
          carb: { type: "NUMBER", description: "Carbohydrates in grams" },
          protein: { type: "NUMBER", description: "Protein in grams" },
          sugar: { type: "NUMBER", description: "Sugar in grams" },
          confidence: {
            type: "NUMBER",
            description: "Confidence score between 0.0 and 1.0",
          },
        },
        required: [
          "name",
          "calories",
          "fat",
          "carb",
          "protein",
          "sugar",
          "confidence",
        ],
      },
    },
    total_calories: {
      type: "NUMBER",
      description: "Sum of calories across all items",
    },
    total_mass: {
      type: "NUMBER",
      description: "Sum of grams/ml amounts across all ingredients",
    },
    total_fat: {
      type: "NUMBER",
      description: "Sum of fat across all ingredients",
    },
    total_carb: {
      type: "NUMBER",
      description: "Sum of carbohydrates across all ingredients",
    },
    total_protein: {
      type: "NUMBER",
      description: "Sum of protein across all ingredients",
    },
    total_sugar: {
      type: "NUMBER",
      description: "Sum of sugar across all ingredients",
    },
    error: {
      type: "STRING",
      description:
        "Reason if no food detected or image unclear; leave empty string for successful analysis",
      nullable: true,
    },
  },
  required: [
    "ingredients",
    "total_calories",
    "total_mass",
    "total_fat",
    "total_carb",
    "total_protein",
  ],
};

interface IngredientItem {
  name: string;
  grams?: number | null;
  ml?: number | null;
  calories: number;
  fat: number;
  carb: number;
  protein: number;
  sugar: number;
  confidence: number;
}

interface PublicIngredientItem {
  name: string;
  grams: number | null;
  ml: number | null;
  calories: number;
  fat: number;
  carb: number;
  protein: number;
  sugar: number;
  confidence: number;
}

interface AnalysisResult {
  ingredients: IngredientItem[];
  total_calories: number;
  total_mass: number;
  total_fat: number;
  total_carb: number;
  total_protein: number;
  total_sugar: number;
  error?: string;
}

function buildSummaryName(items: PublicIngredientItem[]): string {
  if (items.length === 0) return "AI Scanned Meal";

  const firstName = items[0].name?.trim() || "AI Scanned Meal";
  if (items.length === 1) return firstName;
  return `${firstName} + ${items.length - 1} more`;
}

function normalizeGeminiJsonText(rawText: string): string {
  const trimmed = rawText.trim();

  // Gemini can occasionally wrap JSON in markdown fences even when structured output is enabled.
  const fenceMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fenceMatch?.[1]) return fenceMatch[1].trim();

  return trimmed;
}

function parseGeminiJson(rawText: string): AnalysisResult {
  const normalized = normalizeGeminiJsonText(rawText);

  try {
    return JSON.parse(normalized) as AnalysisResult;
  } catch {
    // Fall back to the widest object slice if Gemini adds stray text around the payload.
    const firstBrace = normalized.indexOf("{");
    const lastBrace = normalized.lastIndexOf("}");

    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return JSON.parse(
        normalized.slice(firstBrace, lastBrace + 1),
      ) as AnalysisResult;
    }

    throw new Error("Unable to parse Gemini JSON output");
  }
}

function toNonNegativeNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.max(0, value);
  }

  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return Math.max(0, parsed);
    }
  }

  return 0;
}

function toOptionalPositiveNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return value;
  }

  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number(value);
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed;
    }
  }

  return null;
}

function toConfidence(value: unknown): number {
  const confidence = toNonNegativeNumber(value);
  if (confidence > 1) return 1;
  return confidence;
}

function looksLikeDrink(name: string): boolean {
  const normalized = name.toLowerCase();
  const drinkHints = [
    "drink",
    "tea",
    "coffee",
    "latte",
    "juice",
    "soda",
    "cola",
    "water",
    "milk",
    "smoothie",
    "beer",
    "wine",
    "cocktail",
    "soup",
    "奶茶",
    "咖啡",
    "果汁",
    "湯",
    "水",
  ];
  return drinkHints.some((hint) => normalized.includes(hint));
}

function normalizeIngredient(
  item: IngredientItem,
  index: number,
): PublicIngredientItem {
  const normalizedName =
    typeof item.name === "string" && item.name.trim().length > 0
      ? item.name.trim()
      : `ingredient-${index + 1}`;

  let grams = toOptionalPositiveNumber(item.grams);
  let ml = toOptionalPositiveNumber(item.ml);

  if (grams != null && ml != null) {
    if (looksLikeDrink(normalizedName)) {
      grams = null;
    } else {
      ml = null;
    }
  }

  return {
    name: normalizedName,
    grams,
    ml,
    calories: toNonNegativeNumber(item.calories),
    fat: toNonNegativeNumber(item.fat),
    carb: toNonNegativeNumber(item.carb),
    protein: toNonNegativeNumber(item.protein),
    sugar: toNonNegativeNumber(item.sugar),
    confidence: toConfidence(item.confidence),
  };
}

function resolveTotalNumber(value: unknown, fallback: number): number {
  const parsed = toNonNegativeNumber(value);
  if (parsed > 0) {
    return parsed;
  }
  return Math.max(0, fallback);
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

function resolveRequestedModel(rawModel: unknown): string | null {
  if (typeof rawModel !== "string") {
    return null;
  }

  const normalized = rawModel.trim();
  return normalized.length > 0 ? normalized : null;
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
  models: string[],
): Promise<{ response: Response; model: string; attemptedModels: string[] }> {
  let lastError: unknown = null;
  const attemptedModels: string[] = [];

  for (let modelIndex = 0; modelIndex < models.length; modelIndex++) {
    const model = models[modelIndex];

    try {
      const result = await callGeminiSingleModelWithRetry(
        inlineImageData,
        mimeType,
        geminiKey,
        model,
      );
      attemptedModels.push(`${result.apiVersion}/${model}`);
      const response = result.response;

      if (response.ok) {
        return { response, model, attemptedModels };
      }

      const hasFallback = modelIndex < models.length - 1;
      if (hasFallback && RETRYABLE_STATUS_CODES.has(response.status)) {
        console.warn(
          `Gemini model ${model} returned ${response.status}; falling back to ${
            models[modelIndex + 1]
          }`,
        );
        continue;
      }

      return { response, model, attemptedModels };
    } catch (err) {
      lastError = err;

      const hasFallback = modelIndex < models.length - 1;
      if (hasFallback && isRetryableNetworkError(err)) {
        console.warn(
          `Gemini model ${model} failed with retryable network error; falling back to ${
            models[modelIndex + 1]
          }`,
        );
        continue;
      }

      throw err;
    }
  }

  throw lastError ?? new Error("Gemini request failed");
}

async function callGeminiSingleModelWithRetry(
  inlineImageData: string,
  mimeType: string,
  geminiKey: string,
  model: string,
): Promise<{ response: Response; apiVersion: string }> {
  const response = await callGeminiVersionedEndpointWithRetry(
    inlineImageData,
    mimeType,
    geminiKey,
    model,
  );

  return { response, apiVersion: DEFAULT_GEMINI_API_VERSION };
}

async function callGeminiVersionedEndpointWithRetry(
  inlineImageData: string,
  mimeType: string,
  geminiKey: string,
  model: string,
): Promise<Response> {
  const modelUrl = `https://generativelanguage.googleapis.com/${DEFAULT_GEMINI_API_VERSION}/models/${model}:generateContent`;
  let lastError: unknown = null;

  for (let attempt = 0; attempt <= GEMINI_MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(`${modelUrl}?key=${geminiKey}`, {
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
            // Complex mixed dishes can require more tokens for a complete structured response.
            maxOutputTokens: 4096,
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

interface ProviderErrorDetails {
  message: string;
  status: string;
  code: number | null;
}

function parseProviderErrorDetails(
  providerPayload: string,
): ProviderErrorDetails {
  try {
    const parsed = JSON.parse(providerPayload);
    const providerError = parsed?.error ?? {};

    return {
      message:
        typeof providerError.message === "string" ? providerError.message : "",
      status:
        typeof providerError.status === "string" ? providerError.status : "",
      code: typeof providerError.code === "number" ? providerError.code : null,
    };
  } catch {
    return {
      message: "",
      status: "",
      code: null,
    };
  }
}

function resolveAiErrorMessage(
  status: number,
  providerPayload: string,
): string {
  const providerError = parseProviderErrorDetails(providerPayload);
  const providerMessage = providerError.message.trim();
  const normalized = providerPayload.toLowerCase();

  if (
    status === 429 ||
    normalized.includes("resource_exhausted") ||
    normalized.includes("rate limit") ||
    normalized.includes("quota")
  ) {
    return "AI provider rate limit reached. Please retry in about 1 minute.";
  }

  if (
    status === 408 ||
    normalized.includes("timed out") ||
    normalized.includes("timeout")
  ) {
    return "AI provider timed out. Please retry in 10-30 seconds.";
  }

  if (
    status === 401 ||
    normalized.includes("invalid api key") ||
    normalized.includes("api key not valid")
  ) {
    return "AI provider authentication failed. Please verify GEMINI_API_KEY.";
  }

  if (
    status === 403 ||
    normalized.includes("permission_denied") ||
    normalized.includes("permission denied") ||
    normalized.includes("insufficient permission")
  ) {
    return "AI provider access denied. Please enable Gemini API and check key restrictions.";
  }

  if (
    status === 404 ||
    providerError.status.toLowerCase() === "not_found" ||
    normalized.includes("not found for api version") ||
    normalized.includes("not supported for generatecontent")
  ) {
    return "Configured Gemini model is unavailable for generateContent on v1beta. Please use a supported model (for example gemini-2.5-flash or gemini-3-flash-preview).";
  }

  if (
    status === 400 &&
    (normalized.includes("failed_precondition") ||
      normalized.includes("location is not supported") ||
      normalized.includes("user location is not supported"))
  ) {
    return "AI provider rejected this request in the current region. Please use a supported region/project for Gemini API.";
  }

  if (
    status >= 500 ||
    normalized.includes("unavailable") ||
    normalized.includes("high demand") ||
    normalized.includes("busy")
  ) {
    return "AI provider is temporarily unavailable due to high demand. Please retry in 10-30 seconds.";
  }

  if (providerMessage.length > 0) {
    return `AI provider error: ${providerMessage}`;
  }

  return "Failed to analyze image. Please retake and try again.";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    const body = await req.json();
    const requestedModel = resolveRequestedModel(body?.model);
    const modelsToTry =
      requestedModel != null ? [requestedModel] : GEMINI_MODELS;

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
    let selectedModel = GEMINI_PRIMARY_MODEL;
    let attemptedModels: string[] = [];
    const geminiStartedAt = Date.now();
    try {
      const result = await callGeminiWithRetry(
        inlineImageData,
        mimeType,
        geminiKey,
        modelsToTry,
      );
      geminiRes = result.response;
      selectedModel = result.model;
      attemptedModels = result.attemptedModels;
    } catch (err) {
      console.error(
        "Gemini network error:",
        redactSecrets(extractErrorMessage(err)),
      );
      return errorResponse(
        "AI_UNAVAILABLE",
        "AI provider is temporarily unavailable. Please retry in 10-30 seconds.",
        503,
      );
    }

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      console.error(
        `Gemini API error (${geminiRes.status}) [models: ${
          attemptedModels.join(" -> ") || selectedModel
        }]:`,
        redactSecrets(errText),
      );

      const resolvedMessage = resolveAiErrorMessage(geminiRes.status, errText);
      return errorResponse(
        "AI_ERROR",
        resolvedMessage,
        geminiRes.status === 429 ||
          geminiRes.status >= 500 ||
          geminiRes.status === 408
          ? 503
          : 502,
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
      analysis = parseGeminiJson(rawText);
    } catch {
      console.error("Failed to parse Gemini response:", rawText);
      return errorResponse(
        "AI_PARSE_ERROR",
        "AI response format error, please retake photo",
        502,
      );
    }

    const ingredients = (analysis.ingredients ?? []).map(normalizeIngredient);

    if (analysis.error || ingredients.length === 0) {
      return jsonResponse({
        success: false,
        code: "NO_FOOD_DETECTED",
        error: analysis.error ?? "No food or drink detected",
        image: {
          path: imagePath,
          url: imageUrl,
        },
        meal_date: mealDate,
        ingredients: [],
        total_calories: 0,
        total_mass: 0,
        total_fat: 0,
        total_carb: 0,
        total_protein: 0,
        total_sugar: 0,
      });
    }

    const totalCalories = resolveTotalNumber(
      analysis.total_calories,
      ingredients.reduce((sum, item) => sum + item.calories, 0),
    );
    const totalMass = resolveTotalNumber(
      analysis.total_mass,
      ingredients.reduce((sum, item) => sum + (item.grams ?? item.ml ?? 0), 0),
    );
    const totalFat = resolveTotalNumber(
      analysis.total_fat,
      ingredients.reduce((sum, item) => sum + item.fat, 0),
    );
    const totalCarb = resolveTotalNumber(
      analysis.total_carb,
      ingredients.reduce((sum, item) => sum + item.carb, 0),
    );
    const totalProtein = resolveTotalNumber(
      analysis.total_protein,
      ingredients.reduce((sum, item) => sum + item.protein, 0),
    );
    const totalSugar = resolveTotalNumber(
      analysis.total_sugar,
      ingredients.reduce((sum, item) => sum + item.sugar, 0),
    );

    const dbTotalCalories = Math.round(totalCalories);
    const dbTotalProtein = Math.round(totalProtein);
    const dbTotalCarbs = Math.round(totalCarb);
    const dbTotalFat = Math.round(totalFat);
    const dbTotalSugar = Math.round(totalSugar);

    const analysisSummaryName = buildSummaryName(ingredients);

    const admin = createAdminClient();

    const { data: analysisRow, error: analysisInsertError } = await admin
      .from("ai_meal_analyses")
      .insert({
        user_id,
        meal_date: mealDate,
        image_path: imagePath,
        image_url: imageUrl,
        ai_summary_name: analysisSummaryName,
        ai_items: ingredients,
        ai_total_calories: dbTotalCalories,
        ai_total_protein: dbTotalProtein,
        ai_total_carbs: dbTotalCarbs,
        ai_total_fat: dbTotalFat,
        ai_total_sugar: dbTotalSugar,
        ai_model: selectedModel,
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
      image: {
        path: imagePath,
        url: imageUrl,
      },
      meal_date: mealDate,
      ingredients,
      total_calories: totalCalories,
      total_mass: totalMass,
      total_fat: totalFat,
      total_carb: totalCarb,
      total_protein: totalProtein,
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
