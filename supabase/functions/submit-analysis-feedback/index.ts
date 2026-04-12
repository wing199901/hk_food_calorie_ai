// supabase/functions/submit-analysis-feedback/index.ts
// -------------------------------------------------------------
// App submits user confirmation status for one AI analysis.
// This endpoint writes ai_meal_analyses via service role.
// -------------------------------------------------------------

import {
  createAdminClient,
  createUserClient,
  requireUserId,
} from "../_shared/auth.ts";
import { handleCors, jsonResponse, errorResponse } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return handleCors();

  try {
    const { analysis_id, meal_record_id, is_correct } = await req.json();

    if (!analysis_id || typeof analysis_id !== "string") {
      return errorResponse("MISSING_ANALYSIS_ID", "Missing analysis_id", 400);
    }

    if (!meal_record_id || typeof meal_record_id !== "string") {
      return errorResponse(
        "MISSING_MEAL_RECORD_ID",
        "Missing meal_record_id",
        400,
      );
    }

    if (typeof is_correct !== "boolean") {
      return errorResponse(
        "INVALID_IS_CORRECT",
        "is_correct must be boolean",
        400,
      );
    }

    const userClient = createUserClient(req);
    let user_id: string;
    try {
      user_id = await requireUserId(userClient);
    } catch {
      return errorResponse("UNAUTHORIZED", "Unauthorized", 401);
    }

    const admin = createAdminClient();

    const { data: analysisRow, error: analysisFetchError } = await admin
      .from("ai_meal_analyses")
      .select("id, user_id")
      .eq("id", analysis_id)
      .single();

    if (analysisFetchError || !analysisRow) {
      return errorResponse("ANALYSIS_NOT_FOUND", "Analysis not found", 404);
    }

    if (analysisRow.user_id !== user_id) {
      return errorResponse(
        "FORBIDDEN",
        "Not allowed to update this analysis",
        403,
      );
    }

    const { data: mealRecordRow, error: mealRecordFetchError } = await admin
      .from("meal_records")
      .select("id, user_id, deleted_at")
      .eq("id", meal_record_id)
      .eq("user_id", user_id)
      .single();

    if (
      mealRecordFetchError ||
      !mealRecordRow ||
      mealRecordRow.deleted_at !== null
    ) {
      return errorResponse(
        "MEAL_RECORD_NOT_FOUND",
        "Meal record not found",
        404,
      );
    }

    const feedbackStatus = is_correct ? "confirmed" : "confirmed_with_edit";
    const confirmedAt = new Date().toISOString();

    const { error: updateError } = await admin
      .from("ai_meal_analyses")
      .update({
        meal_record_id,
        is_correct,
        feedback_status: feedbackStatus,
        confirmed_at: confirmedAt,
      })
      .eq("id", analysis_id)
      .eq("user_id", user_id);

    if (updateError) {
      return errorResponse(
        "ANALYSIS_FEEDBACK_UPDATE_FAILED",
        "Failed to update analysis feedback",
        500,
      );
    }

    return jsonResponse({
      success: true,
      analysis_id,
      feedback_status: feedbackStatus,
      confirmed_at: confirmedAt,
    });
  } catch (err) {
    console.error("submit-analysis-feedback error:", err);
    return errorResponse("INTERNAL_ERROR", "Internal server error", 500);
  }
});
