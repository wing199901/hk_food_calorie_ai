// supabase/functions/search-foods/index.ts
// ─────────────────────────────────────────────
// V2: 手動搜尋香港食物資料庫
// 使用 pg_trgm fuzzy search（中文 + 英文）
// ─────────────────────────────────────────────

import { createAdminClient } from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    const { query, limit } = await req.json();

    if (!query || String(query).trim().length === 0) {
      return errorResponse("MISSING_PARAM", "Missing query");
    }

    const supabase = createAdminClient();

    const searchLimit = Math.min(limit ?? 20, 50);
    const searchTerm = `%${String(query).trim()}%`;

    // ── Search by Chinese name OR English name ──
    const { data: foods, error } = await supabase
      .from("hk_foods")
      .select(
        "id, name, name_en, calories_per_100g, protein_per_100g, carbs_per_100g, fat_per_100g, typical_portion, typical_calories, category",
      )
      .or(`name.ilike.${searchTerm},name_en.ilike.${searchTerm}`)
      .limit(searchLimit);

    if (error) {
      console.error("Search error:", error);
      return errorResponse("DB_QUERY_ERROR", "Search failed", 500);
    }

    return jsonResponse({
      success: true,
      query: String(query).trim(),
      count: foods?.length ?? 0,
      foods: foods ?? [],
    });
  } catch (err) {
    console.error("search-foods error:", err);
    return errorResponse(
      "INTERNAL_ERROR",
      err instanceof Error ? err.message : "Internal error",
      400,
    );
  }
});
