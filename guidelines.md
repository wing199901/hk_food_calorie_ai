# FitCalorie — Project Guidelines

## Overview

**FitCalorie** 係專為香港人設計嘅 AI 食物熱量追蹤 App。用戶影食物相（點心、茶餐廳、燒味、西餐、日韓、東南亞、甜品、飲品等），用 Google Gemini 自動識別菜餚、估計真實份量、計算熱量同營養素，並儲存每日紀錄。

---

## Tech Stack

| Layer            | Technology                                       |
| ---------------- | ------------------------------------------------ |
| Mobile App       | Flutter (Dart SDK `^3.11.0`)                     |
| Backend / DB     | Supabase (PostgreSQL + RLS)                      |
| Serverless Logic | Supabase Edge Functions (Deno / TypeScript)      |
| AI               | Google Gemini 2.5 Flash                          |
| Auth             | Supabase Auth                                    |
| Local State      | `shared_preferences` via `StorageService`        |
| Charts           | `fl_chart ^0.70.2`                               |
| Env Secrets      | `envied` + `build_runner` (generated `lib/env/`) |

---

## Database Schema

### Tables

| Table           | Primary Key       | Description                                                            |
| --------------- | ----------------- | ---------------------------------------------------------------------- |
| `user_profiles` | `user_id` (uuid)  | Age, weight, height, waistline, gender, activity level, calorie target |
| `body_metrics`  | `(user_id, date)` | Daily weight & waistline snapshots                                     |
| `meal_records`  | `id` (text)       | AI-parsed meal entries; `items` stored as JSONB array                  |

### `meal_records.items` — JSONB element schema

Each element matches the structure returned by the Gemini prompt in `analyze-meal`:

```json
{
  "name_zh": "蛋撻",
  "name_en": "Egg Tart",
  "type": "food",
  "portion_size": 1,
  "portion_unit": "piece",
  "portion_grams": 75,
  "portion_ml": null,
  "calories": 220,
  "protein": 4,
  "carbs": 28,
  "fat": 10,
  "sugar": 12,
  "confidence": 0.95
}
```

> `type` 係 `"food"` 或 `"drink"`。`portion_grams` 用於固體食物；`portion_ml` 用於飲品 — 兩個唔可以同時有值。

### RLS

所有 table 都要執行 Row Level Security，所有 policy 用 `auth.uid() = user_id`。永遠唔好喺 client 端 bypass RLS。

---

## Edge Functions

所有 function 都係 **POST**，需要 `Authorization: Bearer <jwt>`，成功回傳：

```json
{ "success": true, ... }
```

失敗回傳 `{ "success": false, "error": "message" }` 加埋對應 HTTP status code。

| Function              | Purpose                                             | Secrets          |
| --------------------- | --------------------------------------------------- | ---------------- |
| `analyze-meal`        | Gemini AI 分析相片 → 解析食物 → 寫入 `meal_records` | `GEMINI_API_KEY` |
| `get-daily-summary`   | 拉取每日營養總結 + AI tip                           | —                |
| `update-record`       | 更新食物項目並重新計算 totals                       | —                |
| `delete-record`       | 軟刪除（設 `deleted_at`）或硬刪除                   | —                |
| `generate-ai-insight` | 每週／月 AI 飲食分析報告                            | `GEMINI_API_KEY` |
| `cleanup-old-records` | Cron — 永久清除軟刪除紀錄                           | —                |

### AI System Prompt（`analyze-meal` 必須使用）

```typescript
const SYSTEM_PROMPT = `你係專業營養師，可以分析任何菜系嘅食物同飲品相片（中式、西式、日韓、東南亞、甜品、飲品等），只返嚴格 JSON（唔好加任何解釋）：
{
  "items": [
    {
      "name_zh": "食物名（繁體中文）",
      "name_en": "English Name",
      "type": "food" 或 "drink",
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
```

### Image Handling（client 端壓縮規則）

喺送去 Edge Function 前**必須壓縮**：

- 使用 `image` package（`img.copyResize` + `encodeJpg quality: 85`）
- 最長邊限制 1280px
- 壓縮後轉 base64 傳送
- 目標大小：< 1.5MB（base64 後）
- 格式必須為 JPEG

### Local Development

```bash
# 啟動本地 Supabase（需要 Docker）
supabase start

# 本地跑 edge functions
make serve-functions   # 使用 supabase/.env.local

# 本地 base URL
http://127.0.0.1:54321/functions/v1
```

---

## Project Visual Style

App 採用 iOS 風格嘅簡潔設計，所有設計決定必須符合以下規則。

### Colours (`AppTheme`)

| Token             | Hex       | Usage                                 |
| ----------------- | --------- | ------------------------------------- |
| `primary`         | `#10B981` | 主品牌綠 — 按鈕、header、active 狀態  |
| `secondary`       | `#34D399` | Gradient 尾色、高亮                   |
| `accent`          | `#FF6B35` | 暖橙色 — 熱量數字、重點數據、主要 CTA |
| `background`      | `#F8FAFB` | Scaffold 背景                         |
| `card`            | `#FFFFFF` | Card 表面                             |
| `muted`           | `#F3F4F6` | Chip 背景、分隔線                     |
| `mutedForeground` | `#6B7280` | 次要標籤                              |
| `foreground`      | `#1A1A1A` | 主要文字                              |
| `destructive`     | `#EF4444` | 刪除、錯誤狀態                        |
| `warning`         | `#FBBF24` | 警告提示                              |

### Typography & Shape

- Font family: `SF Pro Display`
- Cards: `borderRadius: 16`，elevation `0`，thin `border` side
- Buttons: `borderRadius: 16`，vertical padding `16`，elevation `2`
- Inputs: `borderRadius: 12`，filled white，focused border `primary` width `2`
- Gradients: `AppTheme.primaryGradient`（綠→綠）或 `AppTheme.primaryToAccent`（綠→橙）

### 8-Point Grid System

所有 spacing、sizing、padding 必須係 **8 的倍數**，細緻微調用 **4**：

| Token | Value | 用途                                      |
| ----- | ----- | ----------------------------------------- |
| `4`   | 4px   | Icon 同文字之間嘅細間距、badge padding    |
| `8`   | 8px   | 同一組 element 之間、chip 內距            |
| `12`  | 12px  | Card 內小間距、list item 之間             |
| `16`  | 16px  | Card padding、section 內距、input padding |
| `24`  | 24px  | Card 與 card 之間、section 上下間距       |
| `32`  | 32px  | Page 頂部空間、大型 section 分隔          |
| `48`  | 48px  | Hero block 上下、空狀態插圖間距           |
| `64`  | 64px  | Page 級別嘅大塊留白                       |

**規則：**

- 唔好用奇數值（例如 `5`、`7`、`13`）
- 唔好用 `3` 或 `6` — 用 `4` 或 `8` 代替
- Icon size 用 `16`、`20`、`24`、`32`、`40`、`48`
- 所有 `SizedBox` / `Padding` / `margin` 必須用以上 token 值
- `BorderRadius` 用 `4`、`8`、`12`、`16`、`24` — 唔好用 `10`、`15` 等非格系值

```dart
// ✅ 正確
Padding(padding: EdgeInsets.all(16))
SizedBox(height: 24)
BorderRadius.circular(16)

// ❌ 錯誤
Padding(padding: EdgeInsets.all(15))
SizedBox(height: 22)
BorderRadius.circular(10)
```

### Chart Style (`analysis_page`)

- iOS Screen Time 風格 card 佈局
- 每個 chart card 頂部有浮動 title badge
- Bar chart 用 SMTWTFS x-axis label
- `maxY` 向上取整到最近 2000；`midY = maxY / 2` 永遠係整數-k
- Summary chips 取代 legend items
- 用 `ExtraLinesData` 喺 `y=0` 同 `y=maxY` 加橫線
- Tap bar 會更新 card subtitle 為選中日期
- 展開詳情 panel 冇 close icon，冇 footer hint text

### General UI Rules

- 永遠唔好 hardcode 顏色 — 必須用 `AppTheme.*`
- 永遠唔好 hardcode text style — 從 `Theme.of(context).textTheme` 取
- 所有 spacing 跟從 **8-Point Grid System**（見上方）
- 用 `BorderRadius.circular()` — 只用格系值（4、8、12、16、24）
- 所有 UI 文字以繁體中文為主

---

## Coding Conventions

- **Dart**: 跟 `flutter_lints`；盡用 `const` constructors + trailing commas
- **Null safety**: collection 內用 `if (x != null) x` — 唔好用 `?` null-aware collection element 語法（當前 SDK 唔支援）
- **Services**: 所有 Supabase 呼叫必須經過 `SupabaseService`；唔好喺 page widget 直接呼叫 `supabase.from()`
- **Edge functions**: 共用工具放 `supabase/functions/_shared/`；error 回傳必須用 shared `errorResponse` helper
- **Schema**: `supabase/schema.sql` 係唯一 source of truth — DB 結構有改動就要同步更新，再用 DB container 重新執行

---

## Communication

- **所有回覆請用廣東話（香港中文）**，技術術語可保留英文（例如 `widget`、`null safety`、`RLS`）。
- 解釋概念時用貼地例子，唔好過度正式。
