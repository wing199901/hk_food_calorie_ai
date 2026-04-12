// supabase/functions/generate-ai-insight/index.ts
// ─────────────────────────────────────────────
// V3: AI generated insights with strict output schema, retry logic, and focus scoping.
// ─────────────────────────────────────────────

import { createUserClient, requireUserId } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

const GEMINI_MODEL = "gemini-2.5-flash";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;
const GEMINI_TIMEOUT_MS = 20_000;
const GEMINI_MAX_RETRIES = 2;
const RETRYABLE_STATUS_CODES = new Set([408, 429, 500, 502, 503, 504]);

const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    summary: { type: "STRING", description: "Overall summary of the period" },
    analysis: {
      type: "STRING",
      description: "Detailed analysis focusing on the requested area",
    },
    trends: {
      type: "ARRAY",
      items: { type: "STRING" },
      description: "List of key observations or trends",
    },
    recommendations: {
      type: "ARRAY",
      items: { type: "STRING" },
      description:
        "2-3 specific, actionable recommendations tailored to Hong Kong diet context",
    },
  },
  required: ["summary", "analysis", "trends", "recommendations"],
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
): Promise<Response> {
  let lastError: unknown = null;

  for (let attempt = 0; attempt <= GEMINI_MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(`${GEMINI_URL}?key=${geminiKey}`, {
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

    const systemInstruction = `你係一個專業嘅香港營養師 AI。你專長於分析用戶嘅飲食記錄並給予個人化及符合香港飲食文化嘅建議，並特別針對用戶指定嘅分析焦點 ('${focus}') 提供深入見解。`;

    const insightPrompt = `以下係用戶過去${
      period === "week" ? "一星期" : "一個月"
    }嘅飲食數據。請以繁體中文 (廣東話口吻) 根據分析焦點 '${focus}'，提供專業見解。
如果有資料不足，請根據現有資料進行分析，不需要額外確認。

焦點解釋:
- general: 整體飲食表現，包含熱量和營養分佈。
- bmi: 就用戶身高體重及飲食結構與減重/維持體重進行連結分析。
- macronutrients: 重點分析蛋白質、碳水化合物和脂肪的攝取比例。
- energy: 重點分析熱量攝取與每日目標的達標狀況及穩定度。

數據：
${summaryForAI}`;

    let geminiRes: Response;
    try {
      geminiRes = await callGeminiWithRetry(
        insightPrompt,
        systemInstruction,
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
        const retryRes = await callGeminiWithRetry(
          insightPrompt,
          systemInstruction,
          geminiKey,
        );
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
          summary: "未能成功解析報告資料",
          analysis: "分析產生失敗",
          trends: [],
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
