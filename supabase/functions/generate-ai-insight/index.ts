// supabase/functions/generate-ai-insight/index.ts
// ─────────────────────────────────────────────
// V3: AI generated insights with strict output schema, retry logic, and focus scoping.
// ─────────────────────────────────────────────

import { createUserClient, requireUserId } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const GEMINI_PRIMARY_MODEL = "gemini-2.5-flash";
const GEMINI_FALLBACK_MODEL = "gemini-3-flash-preview";
const DEFAULT_GEMINI_API_VERSION = "v1beta";
const GEMINI_MODELS = Array.from(
  new Set([GEMINI_PRIMARY_MODEL, GEMINI_FALLBACK_MODEL].filter(Boolean)),
);
const GEMINI_TIMEOUT_MS = 20_000;
const GEMINI_MAX_RETRIES = 2;
const RETRYABLE_STATUS_CODES = new Set([408, 429, 500, 502, 503, 504]);

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    summary: {
      type: "STRING",
      description: "Short insight summary (1-2 sentences)",
    },
    recommendations: {
      type: "ARRAY",
      items: { type: "STRING" },
      description: "2-3 short tips, one sentence each",
    },
  },
  required: ["summary", "recommendations"],
};

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

function normalizeGeminiJsonText(rawText: string): string {
  const trimmed = rawText.trim();

  // Gemini may occasionally wrap JSON in markdown fences despite responseMimeType.
  const fenceMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (fenceMatch?.[1]) return fenceMatch[1].trim();

  return trimmed;
}

function parseGeminiJson(rawText: string): Record<string, unknown> {
  const normalized = normalizeGeminiJsonText(rawText);

  try {
    return JSON.parse(normalized);
  } catch {
    // Try parsing the widest object slice if extra tokens surround the JSON.
    const firstBrace = normalized.indexOf("{");
    const lastBrace = normalized.lastIndexOf("}");
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      return JSON.parse(normalized.slice(firstBrace, lastBrace + 1));
    }
    throw new Error("Unable to parse Gemini JSON output");
  }
}

async function callGeminiWithRetry(
  prompt: string,
  systemInstruction: string,
  geminiKey: string,
  models: string[],
): Promise<{ response: Response; model: string; attemptedModels: string[] }> {
  let lastError: unknown = null;
  const attemptedModels: string[] = [];

  for (let modelIndex = 0; modelIndex < models.length; modelIndex++) {
    const model = models[modelIndex];

    try {
      const response = await callGeminiSingleModelWithRetry(
        prompt,
        systemInstruction,
        geminiKey,
        model,
      );
      attemptedModels.push(`${DEFAULT_GEMINI_API_VERSION}/${model}`);

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
  prompt: string,
  systemInstruction: string,
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
            parts: [{ text: systemInstruction }],
          },
          contents: [
            {
              parts: [{ text: prompt }],
            },
          ],
          generationConfig: {
            temperature: 0.7,
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
    const { period, focus = "general" } = await req.json();

    if (!period || !["week", "month"].includes(period)) {
      return errorResponse("INVALID_PARAM", "period must be 'week' or 'month'");
    }
    const validFocuses = ["general", "bmi", "macronutrients", "energy"];
    if (!validFocuses.includes(focus)) {
      return errorResponse(
        "INVALID_PARAM",
        `focus must be one of: ${validFocuses.join(", ")}`,
      );
    }

    const supabase = createUserClient(req);
    let user_id: string;
    try {
      user_id = await requireUserId(supabase);
    } catch (e) {
      return errorResponse("UNAUTHORIZED", "Unauthorized", 401);
    }

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
        "meal_date, items, total_calories, total_protein, total_carbs, total_fat, total_sugar",
      )
      .eq("user_id", user_id)
      .gte("meal_date", startStr)
      .lte("meal_date", endStr)
      .is("deleted_at", null)
      .order("meal_date", { ascending: true });

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
      {
        calories: number;
        protein: number;
        carbs: number;
        fat: number;
        sugar: number;
      }
    >();

    for (const rec of records ?? []) {
      const day = dailyMap.get(rec.meal_date) ?? {
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
      dailyMap.set(rec.meal_date, day);
    }

    const chartsData = Array.from(dailyMap.entries())
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([meal_date, data]) => ({ meal_date, ...data }));

    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    if (!geminiKey)
      return errorResponse(
        "CONFIG_ERROR",
        "GEMINI_API_KEY not configured",
        500,
      );

    const summaryForAI = JSON.stringify({
      period,
      focus,
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

    const systemInstruction = `You are a professional Hong Kong nutritionist AI. You specialize in analyzing users' dietary records and providing practical, personalized recommendations aligned with Hong Kong eating habits. Focus deeply on the requested focus ('${focus}').

  Always return all user-facing report fields in English only: summary and recommendations.
  Keep the tone friendly, practical, and concise.
  Length limits:
  - summary: 1-2 short sentences.
  - recommendations: 2-3 short tips, one sentence each, no emojis.`;

    const insightPrompt = `Below is the user's dietary data for the past ${
      period === "week" ? "week" : "month"
    }. Based on focus '${focus}', provide a short insight summary and tips in English.
Return JSON with only these fields: summary (string) and recommendations (array of strings).
If the data is limited, still provide a best-effort insight and do not ask follow-up questions.

Focus definitions:
- general: Overall dietary performance, including calorie intake and nutrient distribution.
- bmi: Link height/weight context with dietary structure for weight-loss or maintenance.
- macronutrients: Analyze the intake balance of protein, carbohydrates, and fat.
- energy: Analyze calorie intake versus daily target attainment and consistency.

Data:
${summaryForAI}`;

    let geminiRes: Response;
    let selectedModel = GEMINI_PRIMARY_MODEL;
    let attemptedModels: string[] = [];
    try {
      const result = await callGeminiWithRetry(
        insightPrompt,
        systemInstruction,
        geminiKey,
        GEMINI_MODELS,
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
        "AI service temporarily unavailable. Please retry in a moment.",
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
      switch (geminiRes.status) {
        case 400:
          return errorResponse(
            "BAD_REQUEST",
            "Invalid request format to AI service",
            500,
          );
        case 403:
          return errorResponse("FORBIDDEN", "AI service access denied", 500);
        case 429:
          return errorResponse(
            "RATE_LIMIT",
            "AI service rate limit exceeded",
            429,
          );
        default:
          return errorResponse(
            "AI_ERROR",
            `AI service returned status ${geminiRes.status}`,
            geminiRes.status === 500 ? 502 : 500,
          );
      }
    }

    const geminiData = await geminiRes.json();
    let rawText =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";

    let report_data;
    try {
      report_data = parseGeminiJson(rawText);
    } catch (firstErr) {
      // One best-effort retry for truncated/invalid JSON responses.
      console.error(
        "Failed to parse Gemini JSON output (first attempt)",
        firstErr,
      );
      try {
        const retryResult = await callGeminiWithRetry(
          insightPrompt,
          systemInstruction,
          geminiKey,
          GEMINI_MODELS,
        );
        const retryRes = retryResult.response;
        if (retryRes.ok) {
          const retryData = await retryRes.json();
          rawText =
            retryData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
          report_data = parseGeminiJson(rawText);
        } else {
          throw new Error(`Retry status ${retryRes.status}`);
        }
      } catch (secondErr) {
        console.error(
          "Failed to parse Gemini JSON output (retry attempt)",
          secondErr,
        );
        report_data = {
          summary: "Unable to parse report data.",
          recommendations: [],
        };
      }
    }

    return jsonResponse({
      success: true,
      period,
      focus,
      date_range: { from: startStr, to: endStr },
      report: report_data,
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
    console.error(
      "generate-ai-insight error:",
      redactSecrets(extractErrorMessage(err)),
    );
    return errorResponse("INTERNAL_ERROR", "Internal server error", 500);
  }
});
