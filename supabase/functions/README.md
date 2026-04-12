# Supabase Edge Functions

## 概覽

| Priority   | Function                   | 目的                                                | Auth  | DB Table           | Secrets          |
| ---------- | -------------------------- | --------------------------------------------------- | ----- | ------------------ | ---------------- |
| **V1 MVP** | `analyze-meal`             | AI 相片辨識食物/飲品（只接受 Storage `image_path`） | JWT   | `ai_meal_analyses` | `GEMINI_API_KEY` |
| **V1**     | `submit-analysis-feedback` | App 以 `analysis_id` 回寫用戶確認狀態與關聯紀錄     | JWT   | `ai_meal_analyses` | –                |
| **V1**     | `update-record`            | Server-side 更新份量 & totals                       | JWT   | `meal_records`     | –                |
| **V1**     | `get-daily-summary`        | 拉取每日總結 + AI tip                               | JWT   | `meal_records`     | –                |
| **V1**     | `delete-record`            | 軟/硬刪除紀錄                                       | JWT   | `meal_records`     | –                |
| V2         | `generate-ai-insight`      | 每週/月飲食報告 + AI 建議                           | JWT   | `meal_records`     | `GEMINI_API_KEY` |
| V2         | `search-foods`             | 搜尋香港食物資料庫                                  | JWT   | `hk_foods`         | –                |
| 維護       | `cleanup-old-records`      | Cron 清理舊紀錄                                     | Admin | `meal_records`     | –                |

## 前置條件

1. 安裝 Supabase CLI:
   ```bash
   brew install supabase/tap/supabase
   ```
2. 登入及連結 project:
   ```bash
   supabase login
   supabase link --project-ref <your-project-ref>
   ```
3. 跑 SQL schema（Supabase Dashboard → SQL Editor）:
   - 確保已跑最新 `schema.sql`（包括 `meal_records` 和 `hk_foods` 表）

4. 設定 Secrets:
   ```bash
   supabase secrets set GEMINI_API_KEY=your_gemini_api_key_here
   ```

## 部署

```bash
# 部署全部
make deploy-functions

# 部署單個
make deploy-fn NAME=analyze-meal

# 本地測試
make serve-functions
```

## API 文檔

### 🔴 analyze-meal (V1 MVP)

**POST** `/functions/v1/analyze-meal`

**Headers:** `Authorization: Bearer <user_jwt>`

**Request:**

```json
{
  "image_path": "<user_id>/20260409/1712661234567.jpg",
  "meal_date": "2026-02-28"
}
```

`image_path` 必填，且必須是已上傳到 `meal-images` bucket 的物件路徑。
`meal-images` 應保持 private；function 會回傳短期可用的 signed `image_url`。

**Response:**

```json
{
  "success": true,
  "analysis_id": "0f4fba86-0c2a-4ccd-8f07-f66be334d06f",
  "meal_date": "2026-02-28",
  "image_path": "<user_id>/20260409/1712661234567.jpg",
  "image_url": "https://<project>.supabase.co/storage/v1/object/sign/meal-images/<user_id>/20260409/1712661234567.jpg?token=<signed-token>",
  "items": [
    {
      "name_zh": "叉燒飯",
      "name_en": "Char Siu Rice",
      "type": "food",
      "portion_size": 1,
      "portion_unit": "plate",
      "portion_grams": 450,
      "portion_ml": null,
      "calories": 650,
      "protein": 35,
      "carbs": 80,
      "fat": 20,
      "sugar": 8,
      "confidence": 0.92
    }
  ],
  "total_calories": 650,
  "total_protein": 35,
  "total_carbs": 80,
  "total_fat": 20,
  "total_sugar": 8
}
```

---

### 🟡 update-record (V1)

**POST** `/functions/v1/update-record`

**Request:**

```json
{
  "record_id": "uuid",
  "updated_items": [
    {
      "name_zh": "叉燒飯",
      "name_en": "Char Siu Rice",
      "portion_size": 0.5,
      "portion_unit": "plate",
      "portion_grams": 225,
      "portion_ml": null,
      "calories": 450,
      "protein": 25,
      "carbs": 55,
      "fat": 15,
      "confidence": 0.92
    }
  ]
}
```

**Response:**

```json
{
  "success": true,
  "record_id": "uuid",
  "new_totals": {
    "total_calories": 450,
    "total_protein": 25,
    "total_carbs": 55,
    "total_fat": 15
  }
}
```

---

### 🟡 get-daily-summary (V1)

**POST** `/functions/v1/get-daily-summary`

**Request:**

```json
{
  "meal_date": "2026-02-28"
}
```

**Response:**

```json
{
  "success": true,
  "meal_date": "2026-02-28",
  "total_calories": 1850,
  "macros": { "protein": 85, "carbs": 210, "fat": 65 },
  "items_count": 5,
  "calorie_target": 2000,
  "remaining_calories": 150,
  "items": [...],
  "ai_tip": "今日蛋白質偏低，建議加啲雞蛋、雞胸或豆腐。"
}
```

---

### 🟡 delete-record (V1)

**POST** `/functions/v1/delete-record`

**Request（刪單條）:**

```json
{
  "record_id": "uuid"
}
```

**Request（刪整日）:**

```json
{
  "meal_date": "2026-02-28"
}
```

**Request（硬刪除）:**

```json
{
  "record_id": "uuid",
  "hard_delete": true
}
```

**Response:**

```json
{
  "success": true,
  "deleted_count": 3,
  "mode": "soft"
}
```

---

### 🔵 generate-ai-insight (V2)

**POST** `/functions/v1/generate-ai-insight`

**Request:**

```json
{
  "period": "week"
}
```

**Response:**

```json
{
  "success": true,
  "period": "week",
  "date_range": { "from": "2026-02-21", "to": "2026-02-28" },
  "report_text": "📊 本週飲食總結\n\n平均每日攝取 1,950 kcal...",
  "charts_data": [
    { "meal_date": "2026-02-21", "calories": 1800, "protein": 75, "carbs": 200, "fat": 60 },
    ...
  ],
  "summary": {
    "total_days": 7,
    "avg_calories": 1950,
    "calorie_target": 2000
  }
}
```

---

### 🔵 search-foods (V2)

**POST** `/functions/v1/search-foods`

**Request:**

```json
{
  "query": "雲吞麵",
  "limit": 10
}
```

**Response:**

```json
{
  "success": true,
  "query": "雲吞麵",
  "count": 3,
  "foods": [
    {
      "id": 1,
      "name": "雲吞麵",
      "name_en": "Wonton Noodle Soup",
      "calories_per_100g": 85,
      "typical_portion": "1碗 (350g)",
      "typical_calories": 300,
      "category": "粥粉麵飯"
    }
  ]
}
```

---

### ⚙️ cleanup-old-records (Admin Cron)

**POST** `/functions/v1/cleanup-old-records`

**Headers:** `Authorization: Bearer <service_role_key>`

**Request:**

```json
{
  "days_old": 365
}
```

**Response:**

```json
{
  "success": true,
  "deleted": 42,
  "soft_deleted_cleaned": 42,
  "ancient_cleaned": 0,
  "cutoff_days": 365
}
```

## DB 架構

`analyze-meal` 會接收 `image_path`，回傳分析結果給 App，並保留 human-in-the-loop 確認流程（用戶按 Save 後先寫入 `meal_records`）。

`analyze-meal` 會先寫入 `ai_meal_analyses`（`feedback_status = pending`），再回傳 `analysis_id` 給 App。
App 端採用 human-in-the-loop：

- 用戶確認 AI 正確後按 Save，才寫入 `meal_records`
- 若 AI 不正確，用戶可先 edit 再 Save
- Save 時 App 會呼叫 `submit-analysis-feedback` 回寫 `ai_meal_analyses`：
  - `is_correct = true` + `feedback_status = confirmed`（無編輯）
  - `is_correct = false` + `feedback_status = confirmed_with_edit`（有編輯）

`ai_meal_analyses` 為內部改善用途：

- 一般 user 沒有直接 `select/insert/update/delete` 權限
- 讀寫只可透過 edge functions（service role）完成

---

### 🟡 submit-analysis-feedback (V1)

**POST** `/functions/v1/submit-analysis-feedback`

**Headers:** `Authorization: Bearer <user_jwt>`

**Request:**

```json
{
  "analysis_id": "0f4fba86-0c2a-4ccd-8f07-f66be334d06f",
  "meal_record_id": "1712661234567",
  "is_correct": false
}
```

**Response:**

```json
{
  "success": true,
  "analysis_id": "0f4fba86-0c2a-4ccd-8f07-f66be334d06f",
  "feedback_status": "confirmed_with_edit",
  "confirmed_at": "2026-04-11T09:12:34.567Z"
}
```

`meal_records` 建議欄位如下：

```
meal_records
├── id (uuid, PK, auto-generated)
├── user_id (uuid, FK → auth.users)
├── meal_date (date, YYYY-MM-DD)
├── image_path (text, nullable, Supabase Storage object path)
├── items (jsonb, 食物陣列)
├── total_calories (integer)
├── total_protein (integer)
├── total_carbs (integer)
├── total_fat (integer)
├── image_url (text, nullable, signed URL snapshot)
├── deleted_at (timestamptz, nullable, soft delete)
├── created_at (timestamptz)
└── updated_at (timestamptz, auto-trigger)
```

`get-daily-summary` 純粹使用 `meal_records` 表（AI 分析 + 手動輸入均存於此表）。

`ai_meal_analyses` 建議欄位如下：

```
ai_meal_analyses
├── id (uuid, PK)
├── user_id (uuid, FK → auth.users)
├── meal_date (date, YYYY-MM-DD)
├── image_path (text, nullable)
├── image_url (text, nullable, signed URL snapshot)
├── ai_summary_name (text)
├── ai_items (jsonb)
├── ai_total_calories/protein/carbs/fat/sugar (integer)
├── ai_model (text, default: gemini-2.5-flash)
├── input_tokens/output_tokens/total_tokens (integer, nullable)
├── image_bytes (integer, default: 0)
├── latency_ms (integer, nullable)
├── meal_record_id (text, nullable)
├── is_correct (boolean, nullable)
├── confirmed_at (timestamptz, nullable)
├── feedback_status (text: pending/confirmed/confirmed_with_edit/discarded)
├── created_at (timestamptz)
└── updated_at (timestamptz)
```

## 本地開發

```bash
# 建立 .env.local
echo "GEMINI_API_KEY=your_key_here" > .env.local

# 啟動本地 function server
make serve-functions

# 測試 (用 curl)
# 方式: 用已上傳 Storage 路徑
curl -X POST http://localhost:54321/functions/v1/analyze-meal \
  -H "Authorization: Bearer <your_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"image_path":"<user_id>/20260409/1712661234567.jpg","meal_date":"2026-02-28"}'
```
