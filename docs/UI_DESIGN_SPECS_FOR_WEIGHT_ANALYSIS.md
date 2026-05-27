# FitCalorie — Detailed UI Design Specification for Weight & Calorie Analysis Pages

**Document Version:** 1.0  
**Purpose:** Complete design handoff for external designer/LLM tools  
**Target Audience:** UI/UX designers, design systems engineers

---

## Table of Contents
1. [Design System Foundation](#design-system-foundation)
2. [Page 1: Healthy Range Detail Page](#page-1-healthy-range-detail-page)
3. [Page 2: Weight Formula Detail Page](#page-2-weight-formula-detail-page)
4. [Page 3: Calorie Surplus Detail Page](#page-3-calorie-surplus-detail-page)
5. [Shared Components](#shared-components)
6. [Flutter Implementation Prompt](#flutter-implementation-prompt)

---

## Design System Foundation

### Color Palette
All colors reference `AppTheme` constants defined in `lib/core/theme/app_theme.dart`:

| Name | Hex | Usage | CSS Value |
|------|-----|-------|-----------|
| **Primary** | #10B981 | Main CTAs, highlights, key metrics | `#10B981` |
| **Accent** | #FF6B35 | Secondary highlights, warnings, contrast | `#FF6B35` |
| **Destructive** | #EF4444 | Error states, danger actions | `#EF4444` |
| **Background** | #F8FAFB | Page background | `#F8FAFB` |
| **Card** | #FFFFFF | Card/container fill | `#FFFFFF` |
| **Muted** | #F3F4F6 | Subtle backgrounds, disabled states | `#F3F4F6` |
| **Muted Foreground** | #6B7280 | Secondary text, helper text | `#6B7280` |
| **Foreground** | #1A1A1A | Primary text, headings | `#1A1A1A` |
| **Border** | rgba(0,0,0,0.08) | Card borders, dividers | `rgba(0, 0, 0, 0.08)` |

### Spacing System
All spacing references `AppSpacing` constants:

| Name | Value (px) |
|------|-----------|
| **xxs** | 4 |
| **xs** | 8 |
| **sm** | 12 |
| **md** | 16 |
| **lg** | 24 |
| **xl** | 32 |
| **xxl** | 48 |
| **xxxl** | 64 |

### Typography
- **Font:** System default (SF Pro Display on iOS, Roboto fallback on Android)
- **Light Mode:** Text color is always `#1A1A1A` (Foreground)
- **Font Weights:** 400 (regular), 600 (semibold), 700 (bold)

### Border Radius
- **Cards/Containers:** 16px
- **Input fields:** 12px
- **Buttons:** 16px

### App Bar Style (Analysis detail pages)
- **Background:** #F8FAFB (Background)
- **Text Color:** #1A1A1A (Foreground)
- **Title Font:** Semibold 18px
- **Elevation:** None (flat)

---

## Page 1: Healthy Range Detail Page

### URL Route
`/analysis/healthy-range-detail`

### Page Parameters
```dart
{
  currentWeightKg: double?        // User's current weight in kg
  heightCm: double?               // User's height in cm
  lowerKg: double?                // Minimum healthy weight (BMI 18.5)
  upperKg: double?                // Ideal weight (Devine IBW)
  gender: String?                 // "male" or "female"
  unitSystem: String?             // "metric" or "imperial"
}
```

### App Bar
```
Title: "How Your Weight Range Is Calculated"
Style: Font Weight 600, Font Size 18px
Background: #F8FAFB (Background)
Text Color: #1A1A1A (Foreground)
```

### Page Layout
**Main Container:**
- Background: #F8FAFB
- Scroll: SingleChildScrollView
- Padding: 24px (all sides)
- Content arranged in vertical Column

---

### Card 1: "For height... your healthy growth range is..."

**Component Type:** DetailTextCard

**Container Styling:**
- Background: #FFFFFF (White)
- Padding: 16px (all sides)
- Border Radius: 16px
- Border: 1px solid rgba(0,0,0,0.08)

**Text Content (Dynamic):**
```
For height [HEIGHT_TEXT], your healthy growth range is [LOWER_TEXT] to [UPPER_TEXT].

[Paragraph 2]
BMI 18.5 is the minimum healthy threshold. Below it, you are still in the underweight range; above it, your body has a better reserve for energy, immunity, and recovery.

[Paragraph 3 - RichText with highlighted formulas]
Minimum threshold = [LOWER_FORMULA_WITH_NUMBERS]
Meaning: BMI 18.5 is the minimum healthy threshold. Below this point, you are still considered underweight.

Ideal target = [UPPER_FORMULA_WITH_NUMBERS]
Meaning: this is the Devine IBW target, where body load is usually light and the balance is medically favorable.

Summary: your healthy weight range is [LOWER_TEXT] - [UPPER_TEXT].
```

**Text Styling:**
- **Body Text:** Font Size 15px, Line Height 1.45, Color: #1A1A1A
- **Highlighted Formulas:** Font Weight 700, Color: #10B981 (Primary)

**Optional Enhancement: Health Benefits Icon Row**
- **Placement:** Insert between the BMI 18.5 paragraph and the formula block.
- **Layout:** Compact horizontal row (or Wrap on small screens) of two icon+label chips.
- **Icon semantics (no platform binding):**
  - Shield icon labeled "Immunity"
  - Battery icon labeled "Energy reserve"
- **Sizing:** Icon 14-16px, label 12px.
- **Color:** Icon in #10B981 (Primary), label in #6B7280 (Muted Foreground).
- **Optional chip background:** #F3F4F6 (Muted) with 8-10px radius.

**Height Calculation Examples:**
```
If height = 175 cm (male):
- Height Text: "175 cm"
- Lower Text: "56.7 kg" (BMI 18.5 calculation)
- Upper Text: "76.2 kg" (Devine: 50 + 2.3×((175-152.4)/2.54))

If height = 165 cm (female):
- Height Text: "165 cm"
- Lower Text: "50.4 kg" (BMI 18.5 calculation)
- Upper Text: "67.7 kg" (Devine: 45.5 + 2.3×((165-152.4)/2.54))

If using imperial system:
- Height Text: "5'9\" (69.3 in)"
- Weights displayed in lbs
```

**Spacing After Card 1:** 16px margin-bottom

---

### Card 2: Weight Zone Scale (Interactive Slider)

**Component Type:** DetailTextCard with WeightZoneScale widget

**Container Styling:** Same as Card 1

**Title:** No explicit card title. The section starts with a "Weight" label.

**Sub-Components:**

#### A. Weight Header Row + BMI Badge (Dynamic)
**Structure:**
- Left-aligned label: "Weight"
- Large weight value (e.g., "68.2 kg")
- BMI badge pill (e.g., "BMI 20.4") aligned to the baseline

**Styling:**
- Label: Font Size 12px, Font Weight 700, Color #6B7280
- Value: Font Size 32px, Font Weight 800, Color #1A1A1A, letterSpacing -0.8
- Badge padding: 12px horizontal, 6px vertical; pill radius 99
- Badge background: zone color with 14% opacity
- Badge text: zone color

**Dynamic Zone Color Mapping:**
- BMI < 18.5: #EF4444 (Destructive)
- 18.5 <= BMI < 25: #10B981 (Primary)
- 25 <= BMI < 30: #FF6B35 (Accent)
- BMI >= 30: #FBBF24 (Warning)

**Optional Enhancement:** Use `AnimatedContainer` + `AnimatedDefaultTextStyle` (150-200ms) so badge background/text color shifts smoothly while sliding.

#### B. Helper Text
```
"Drag the slider to preview where your weight lands on the zone bar."
```
Font Size 13px, Color #6B7280, Line Height 1.35

#### C. Visual Three-Zone Weight Bar + Markers
**Structure:**
- Full-width horizontal bar divided into 3 equal visual zones
- Zone 1 (Underweight): Red tint
- Zone 2 (Normal Weight): Green tint
- Zone 3 (Overweight): Orange tint

**Bar Styling:**
- Height: 20px
- Border Radius: 999px (pill with overflow clipping)
- Zone segments are visual thirds; actual weights map to positions within each third

**Markers (Above Bar):**
- Dotted vertical indicator lines for Current, Minimum, Ideal
- Marker labels above the bar
  - Current: Color #1A1A1A
  - Minimum: Color #10B981
  - Ideal: Color #3B82F6 (Chart Weight)

**Current Position Indicator:**
- Dotted vertical line aligned to the current weight
- Updates in real-time with slider

**Zone Labels (Below Bar):**
- Three equal columns under the bar
- Font Size 12px, Font Weight 700
- Labels: "Underweight" (Destructive), "Normal" (Primary), "Overweight" (Accent)

**Bar Segment Logic:**
```
Segment 1: Scale Min -> BMI 18.5 threshold
Segment 2: BMI 18.5 -> BMI 25 threshold
Segment 3: BMI 25 -> Scale Max
```

**Example Visual Layout (175cm male):**
```
Scale Min         BMI 18.5              BMI 25              Scale Max
[==== under ====][====== normal ======][====== over ======]
        ^ Minimum       ^ Current/Ideal markers move within these thirds
```

**Spacing:** 12px margin-top, 12px margin-bottom

#### D. Interactive Slider
**Component:** Flutter Slider widget

**Styling (SliderTheme overrides):**
- Active Track Color: #10B981 (Primary)
- Inactive Track Color: #F3F4F6 (Muted)
- Thumb Color: #10B981 (Primary)
- Overlay Color: rgba(16, 185, 129, 0.14)
- Track Height: 6px
- No padding

**Range Calculation (Weight Zone Scale):**
```
Scale Min = max(35.0, min(BMI 18.5 weight, BMI 25 weight) - 16.0)
Scale Max = max(Scale Min + 34.0, max(Ideal weight, BMI 25 weight) + 10.0)
```

**Behavior:**
- User drags thumb left/right
- Updates display weight in real-time
- Clamped to min/max range
- Triggers recalculation of zone bar position and current weight display
- No text input alternative (slider only)

**Spacing:** 8px margin-top, 8px margin-bottom

**Accessibility:**
- Slider labeled with accessible text

#### E. Expansion Tile (Formula Breakdown)
**Title:** "Calculation Formula"
**Content:** (Collapsible section)

Text content:
```
This weight range uses two calculations:

Minimum threshold: [BMI 18.5 formula with numbers]
Ideal weight: [Devine IBW formula with numbers]
Overweight formula: [BMI 25 formula with numbers]
```

**Styling:**
- Collapsible/expandable (initially collapsed)
- Same card background when expanded
- Font Size 13-14px, Color: #1A1A1A
- Formula colors: Minimum = #10B981, Ideal = #3B82F6, Overweight = #FF6B35

**Spacing After Entire Card 2:** 16px margin-bottom

---

### Footer Navigation (Optional)
- Back button (implicit via AppBar back navigation)
- Related links or next step CTAs (if applicable)

---

## Page 2: Weight Formula Detail Page

### URL Route
`/analysis/weight-formula-detail`

### Page Parameters
```dart
{
  heightCm: double?               // User's height in cm
  lowerKg: double?                // Minimum healthy weight (BMI 18.5)
  upperKg: double?                // Ideal weight (Devine IBW)
  baseKg: double                  // Gender-specific base (50 or 45.5 kg)
  heightText: String              // Formatted height string
  lowerText: String               // Formatted lower bound
  upperText: String               // Formatted upper bound
  currentWeightKg: double?        // Current weight in kg
  gender: String?                 // "male" or "female"
  unitSystem: String?             // "metric" or "imperial"
}
```

### App Bar
```
Title: "How We Calculate Your Target Range"
Style: Font Weight 600, Font Size 18px
Background: #F8FAFB (Background)
Text Color: #1A1A1A (Foreground)
```

### Page Layout
**Main Container:**
- Background: #F8FAFB
- Scroll: SingleChildScrollView
- Padding: 24px (all sides)
- Content arranged in vertical Column

---

### Card 1: "How the numbers are calculated"

**Component Type:** DetailTextCard

**Container Styling:** Same as previous page cards

**Content:**

**Heading:**
```
"How the numbers are calculated"
Font Size: 17px, Font Weight: 700, Color: #1A1A1A
```

**Body Text (Bullet-style list):**
```
1. Base weight: 50 kg (male) or 45.5 kg (female).
2. Height adjustment: +2.3 kg per inch above 152.4 cm.
3. Minimum threshold comes from BMI 18.5.
```

**Styling:**
- Font Size: 15px
- Color: #1A1A1A
- Line Height: 1.45
- Left padding for list indentation: 12px
- Spacing between: 10px margin-top (between heading and body)

**Spacing After Card:** 16px margin-bottom

---

### Card 2: "Math Formula"

**Component Type:** DetailTextCard (centered layout)

**Container Styling:** Same as Card 1

**Content Structure:**

**Heading:**
```
"Math Formula"
Font Size: 16px, Font Weight: 700, Color: #1A1A1A
Text Alignment: Center
Margin-bottom: 10px
```

#### Sub-Section A: Minimum Threshold

**Label:**
```
"Minimum threshold: BMI 18.5 x height(m)^2"
Font Size: 14px, Color: #6B7280 (Muted Foreground)
Text Alignment: Center
Margin-bottom: 6px
```

**Formula Result:**
```
Example: "18.5 x (1.75 ^ 2) = 56.7 kg"
Font Size: 15px, Font Weight: 700, Color: #1A1A1A
Text Alignment: Center
```

**Spacing Between Sub-Sections:** 14px margin-top/bottom

#### Sub-Section B: Upper Boundary

**Label:**
```
"Upper boundary: Base weight + 2.3 x ((height_cm - 152.4) / 2.54)"
Font Size: 14px, Color: #6B7280 (Muted Foreground)
Text Alignment: Center
Margin-bottom: 6px
```

**Formula Result:**
```
Example: "50.0 + 2.3 x ((175 - 152.4) / 2.54) = 76.2 kg"
Font Size: 15px, Font Weight: 700, Color: #1A1A1A
Text Alignment: Center
```

**Dynamic Calculation:**
- If `heightCm` is null or 0, display "--"
- Otherwise, show full calculated formula with actual numbers
- Formulas adapt to unit system (metric shows cm/kg, imperial shows in/lbs)

**Optional Enhancement: IBW vs BMI 18.5 Comparison Layout**
- **Layout:** Two-column (side-by-side) on wide screens, stacked on small screens.
- **Left Column:** "Healthy Minimum (BMI 18.5)"
  - Label text: "BMI 18.5 x height(m)^2"
  - Result text: calculated minimum threshold
  - Accent color: #10B981 (Primary)
- **Right Column:** "Ideal Target (IBW)"
  - Label text: "Base weight + 2.3 x ((height_cm - 152.4) / 2.54)"
  - Result text: calculated IBW target
  - Accent color: #3B82F6 (Chart Weight) or #10B981 (Primary)
- **Divider:** Optional vertical line or 12-16px gap between columns
- **Goal:** Make the two formulas visually comparable at a glance

**Spacing After Card:** 16px margin-bottom

---

### Card 3: "When we use IBW vs ABW"

**Component Type:** DetailTextCard

**Container Styling:** Same as previous cards

**Content:**

**Heading:**
```
"When we use IBW vs ABW"
Font Size: 17px, Font Weight: 700, Color: #1A1A1A
Margin-bottom: 10px
```

**Paragraph 1 (Plain Text):**
```
"IBW here follows the Devine base + height adjustment shown above."
Font Size: 15px, Color: #1A1A1A
Line Height: 1.45
Margin-bottom: 8px
```

**Paragraph 2 (RichText with Highlights):**
```
"If actual weight > 120% of IBW, we use ABW for energy targets.
ABW = IBW + 0.4 x (Actual - IBW)
Otherwise, we use actual weight."
```

**Styling Details:**
- Base: Font Size 15px, Color: #1A1A1A, Line Height: 1.45
- Highlighted Line: "ABW = IBW + 0.4 x (Actual - IBW)"
  - Font Weight: 700
  - Color: #10B981 (Primary)

**Spacing After Card:** 16px margin-bottom

---

### Card 4: "Formula Simulator" (Interactive)

**Component Type:** DetailTextCard with AbwFormulaSimulatorCard widget

**Container Styling:** Same as other cards

**Sub-Components:**

#### A. Card Header
```
"Formula Simulator"
Font Size: 17px, Font Weight: 700, Color: #1A1A1A
Margin-bottom: 10px
```

#### B. Instruction Text
```
"Move the slider to see when ABW is used for energy targets."
Font Size: 15px, Color: #1A1A1A
Line Height: 1.45
Margin-bottom: 8px
```

#### C. Fallback Message (if no height provided)
```
"Add your height in profile settings to unlock this simulator."
Font Size: 14px, Color: #6B7280 (Muted Foreground)
Conditional: Display only if height is null
```

#### D. Simulator Content (if height provided)

**Step 1: Three Value Chips**

**Layout:** Horizontal wrap (Wrap widget with spacing)

**Chip 1: Actual Weight**
```
Label: "Actual"
Value: [CURRENT_WEIGHT_FORMATTED] (e.g., "80 kg")
Background: #F3F4F6 (Muted)
Padding: 12px horizontal, 8px vertical
Border Radius: 12px
Font: 13px bold
```

**Chip 2: IBW**
```
Label: "IBW"
Value: [IBW_FORMATTED] (e.g., "76.2 kg")
Same styling as Chip 1
```

**Chip 3: 120% IBW Threshold**
```
Label: "120% IBW"
Value: [THRESHOLD_FORMATTED] (e.g., "91.4 kg")
Same styling as Chip 1
```

**Wrap Spacing:** 8px between chips horizontally, 8px vertical run spacing

**Step 2: Interactive Slider**

**Same styling as Page 1 slider**
- Active Track: #10B981
- Inactive Track: #F3F4F6
- Thumb: #10B981
- Track Height: 6px
- Range: 50% to 150% of estimated IBW
- Key: `'abw_weight_slider'`

**Margin:** 8px top, 8px bottom

**Step 3: TEE Weight Source Display Box**

**Container:**
- Background: #F3F4F6 (Muted)
- Padding: 12px
- Border Radius: 12px
- Width: 100%

**Content:**
```
TEE weight source: [ACTUAL or ABW]
Weight used for TEE: [WEIGHT_VALUE]
Font Size: 14px, Color: #1A1A1A
Font Weight: Regular for "TEE weight source: ", Bold for value
```

**Behavior:**
- Displays "Actual" when slider weight ≤ 120% IBW
- Displays "ABW" when slider weight > 120% IBW
- Changes in real-time as user moves slider
- Key for value text: `'abw_source_value'`

**Step 4: Formula Display with Calculation**

**Content:**
```
ABW = IBW + 0.4 × (Actual - IBW)
ABW = [IBW_VALUE] + 0.4 × ([ACTUAL_VALUE] - [IBW_VALUE])
ABW = [CALCULATED_ABW_VALUE]
```

**Styling:**
- Font Size: 14px
- Base color: #1A1A1A
- Formula operators in bold
- Calculated ABW value in bold, color: #FF6B35 (Accent)
- Left margin: 8px

**Optional Enhancement: IBW vs ABW Switch Visualization**
- **Trigger:** Only animate when crossing the 120% IBW threshold (avoid flicker while sliding near the edge).
- **Visual Behavior:**
  - IBW state fades to 40% opacity.
  - ABW state fades in with Accent color (#FF6B35).
  - Optional helper text appears briefly: "Switching to ABW for accuracy".
- **Animation Style:** Implicit animations (150-200ms), e.g., `AnimatedOpacity` + `AnimatedSwitcher`.
- **Color Pairing:** IBW uses #10B981 (Primary) or #3B82F6 (Chart Weight); ABW uses #FF6B35 (Accent).

**Spacing After Card:** 16px margin-bottom

---

### Footer Navigation
- Optional CTA to next page or home
- Back button (implicit via AppBar)

---

## Page 3: Calorie Surplus Detail Page

### URL Route
`/analysis/calorie-surplus-detail`

### Page Parameters
```dart
{
  // No required parameters; loads TEE from storage provider
}
```

### App Bar
```
Title: "Why +500 kcal per Day?"
Style: Font Weight 600, Font Size 18px
Background: #F8FAFB (Background)
Text Color: #1A1A1A (Foreground)
```

### Page Layout
**Main Container:**
- Background: #F8FAFB
- Scroll: SingleChildScrollView
- Padding: 24px (all sides)
- Content arranged in vertical Column

---

### Card 1: "How the surplus is calculated"

**Component Type:** DetailTextCard

**Container Styling:** Same as previous pages

**Content:**

**Heading:**
```
"How the surplus is calculated"
Font Size: 17px, Font Weight: 700, Color: #1A1A1A
Margin-bottom: 10px
```

**Body Paragraph 1 (Plain Text):**
```
"A common nutrition estimate is that 7,700 kcal surplus ~= 1 kg body weight gain."
Font Size: 15px, Color: #1A1A1A
Line Height: 1.45
Margin-bottom: 8px
```

**Body Paragraph 2 (RichText with Highlighted Values):**
```
Target gain: 0.5 kg/week
Weekly surplus: 0.5 x 7,700 = 3,850 kcal/week
Daily surplus: 3,850 / 7 ~= 550 kcal/day
```

**Styling Details:**
- Base: Font Size 15px, Color: #1A1A1A, Line Height: 1.45
- Highlighted values (0.5 kg/week, 3,850, 550):
  - Font Weight: 700
  - Color: #10B981 (Primary)
- Line breaks between calculation steps
- Margin-bottom of RichText section: 8px

**Optional Enhancement: Timeline / Milestone Forecast**
- **Placement:** Insert between the rich-text calculation block and the final paragraph.
- **Purpose:** Add emotional momentum by showing a near-term milestone.
- **Visibility Rule:** Show only when target weight exists and target > current.
- **Milestone Logic (Dynamic):**
  - remainingKg = targetWeight - currentWeight
  - milestoneGainKg = max(1.0, roundToNearest0.5(remainingKg * 0.25))
  - weeksToMilestone = milestoneGainKg / 0.5
  - Optional: weeksToTarget = remainingKg / 0.5 (smaller caption)
- **Timeline UI:**
  - 3 nodes: "Today", "Next milestone (+X kg)", "Target"
  - Use thin line with dots; highlight milestone node with Primary color
  - Show helper copy: "Estimated ~X weeks to next milestone (based on +0.5 kg/week; depends on consistency)."

**Body Paragraph 3 (Plain Text):**
```
"That is why +500 kcal/day is used as a practical starting point."
Font Size: 15px, Color: #1A1A1A
Line Height: 1.45
```

**Spacing After Card:** 16px margin-bottom

---

### Card 2: "Why +500 kcal is a practical start"

**Component Type:** DetailTextCard

**Container Styling:** Same as Card 1

**Content:**

**Heading:**
```
"Why +500 kcal is a practical start"
Font Size: 17px, Font Weight: 700, Color: #1A1A1A
Margin-bottom: 10px
```

**Body Paragraph 1 (Plain Text):**
```
"Smaller surpluses can be offset by NEAT (extra daily movement), so +500 kcal/day helps create a real net surplus."
Font Size: 15px, Color: #1A1A1A
Line Height: 1.45
Margin-bottom: 8px
```

**Body Paragraph 2 (Plain Text):**
```
"Going much higher tends to add more fat and can feel heavy on digestion. Adjust up or down based on weekly weight trend and appetite tolerance."
Font Size: 15px, Color: #1A1A1A
Line Height: 1.45
```

**Spacing After Card:** 16px margin-bottom

---

### Card 3: "Energy Balance Snapshot" (Interactive)

**Component Type:** DetailTextCard with EnergyBalanceSnapshot widget

**Container Styling:** Same as previous cards

**Content:**

**Heading:**
```
"Energy Balance Snapshot"
Font Size: 17px, Font Weight: 700, Color: #1A1A1A
Margin-bottom: 10px
```

**Sub-Component A: Daily Target Label**

**Content:**
```
"Daily target: [TOTAL_KCAL] kcal"
Example: "Daily target: 2350 kcal"
```

**Styling:**
- Font Size: 15px, Font Weight: 600, Color: #1A1A1A
- Margin-bottom: 8px

**Sub-Component B: Stacked Bar Visualization**

**Layout:**
- Full-width horizontal bar
- Two segments stacked horizontally (TEE on left, Surplus on right)

**Segment 1: TEE (Base Calories)**
- Background Color: #10B981 (Primary)
- Width: (TEE / Total) × 100%
- Example: (1850 / 2350) = 78.7% width

**Segment 2: Surplus (Additional Calories)**
- Background Color: #FF6B35 (Accent)
- Width: (Surplus / Total) × 100%
- Example: (500 / 2350) = 21.3% width

**Bar Styling:**
- Total Height: 14px
- Border Radius: 12px
- Overflow: ClipRRect to maintain border radius
- No gaps between segments

**Margin:** 8px margin-bottom

**Optional Enhancement: Balance Icon Metaphor**
- Place a small balance icon (semantic) near the bar header or to the left of the bar.
- Left pan label: "TEE (burn)"; right pan label: "Food intake (target)".
- Right pan slightly lower to imply surplus.
- Use Primary for left, Accent for right to reinforce the surplus concept.

**Sub-Component C: Three Value Boxes (Horizontal Row)**

**Layout:** Row with three equal-width containers

**Box 1: TEE**
```
Label: "TEE"
Value: "[TEE_VALUE] kcal"
Example: "1850 kcal"

Background: #F3F4F6 (Muted)
Padding: 10px (all sides)
Border Radius: 12px
Spacing: 8px between boxes
```

**Styling:**
- Label: Font Size 11px, Color: #6B7280 (Muted Foreground)
- Value: Font Size 13px, Font Weight: 700, Color: #1A1A1A
- Column layout (label on top, value below)
- Margin-top of value: 2px

**Box 2: +Surplus**
```
Label: "+ Surplus"
Value: "+[SURPLUS_VALUE] kcal"
Example: "+500 kcal"

Same styling as Box 1
```

**Box 3: Target**
```
Label: "Target"
Value: "[TOTAL_VALUE] kcal"
Example: "2350 kcal"

Same styling as Box 1
```

**Spacing After Snapshot:** 16px margin-bottom

---

### Footer: Call-to-Action Buttons

**Button 1: Primary CTA**

**Text:** "Go to log your intake"

**Styling:**
- Type: ElevatedButton
- Background Color: #10B981 (Primary)
- Text Color: White
- Width: 100% (full-width)
- Height: Auto (padding: 14px vertical, auto horizontal)
- Border Radius: 16px
- Font Size: 15px, Font Weight: 700
- Margin-bottom: 8px

**Behavior:** Taps navigate to Log page (tab index 2), close all route overlays

**Button 2: Secondary CTA**

**Text:** "Back to Home energy overview"

**Styling:**
- Type: TextButton
- Text Color: #10B981 (Primary) — inherits from TextButton theme
- Font Size: 15px
- No background
- Padding: Default TextButton padding
- Margin: No additional margin

**Behavior:** Taps navigate to Home page (tab index 0), close all route overlays

**Container Spacing:**
- Button 1 to Button 2: 8px gap (SizedBox)
- Page bottom padding: 24px after buttons

---

## Shared Components

### DetailTextCard

**Purpose:** Reusable container card for content sections

**Styling:**
```dart
Container(
  width: double.infinity,
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: #FFFFFF (AppTheme.card),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: rgba(0,0,0,0.08)),
  ),
  child: childWidget,
)
```

**Usage:** Wraps all major content sections on pages 1–3

### Weight Zone Scale Widget

**Purpose:** Visual representation of weight ranges with interactive slider

**Key Behaviors:**
- Three color zones representing underweight/normal/overweight
- Slider allows user to explore weight ranges
- Current position indicator updates in real-time
- Expansion panel shows formula breakdown

### AbwFormulaSimulatorCard Widget

**Purpose:** Interactive simulator for ABW threshold demonstration

**Key Behaviors:**
- Three stat chips (Actual / IBW / 120% threshold) display values
- Slider range: 50% to 150% of IBW
- TEE weight source label toggles at 120% IBW threshold
- Formula calculation displays when ABW is active
- Disables if height is missing

### EnergyBalanceSnapshot Widget

**Purpose:** Visual summary of daily energy balance

**Key Behaviors:**
- Stacked horizontal bar shows TEE vs surplus proportion
- Three value boxes display TEE, surplus, and total
- Calculated dynamically from storage provider
- Read-only (no interaction)

---

## Design Notes for Implementers

### Responsive Behavior
- All pages use `SingleChildScrollView` to handle varied content heights
- Cards maintain full width with symmetric padding on container
- Text wraps naturally; no fixed widths on text elements
- Buttons are full-width in their containers

### Color Contrast
- All text uses high-contrast colors (#1A1A1A or #FFFFFF) for accessibility
- Highlighted formulas in #10B981 (Primary) provide visual distinction
- Card borders use transparent black (0.08 opacity) for subtle definition

### Spacing Consistency
- 24px top-level padding matches AppSpacing.lg
- 16px between major sections matches AppSpacing.md
- 12px between subsections matches AppSpacing.sm
- 8px for tight gaps matches AppSpacing.xs
- All margins/padding use AppSpacing constants

### Interactive States
- Slider thumb shows overlay color on touch
- Button hover state not specified (platform default)
- Text selection enabled for reference copying

### Accessibility Considerations
- All interactive elements (sliders, buttons) have semantic labels
- Color not sole indicator of meaning (formulas also use bold text)
- Font sizes remain readable (minimum 11px for secondary labels)
- Line heights (1.45) support readability

### Localization Notes
- Currently English-only UI text
- All formulas use standard mathematical notation
- No hardcoded strings in numbers (use dynamic formatting)
- Height/weight formatting respects unit system (metric vs imperial)

---

## Flutter Implementation Prompt

"When implementing `WeightZoneScale` and `AbwFormulaSimulatorCard`, ensure all value transitions use smooth implicit animations (e.g., `AnimatedDefaultTextStyle`, `AnimatedContainer`, `AnimatedOpacity`). As the slider moves, label colors and positions should update fluidly without flicker. Use `RichText` with varied `FontWeight` to emphasize dynamic variables (height, IBW, ABW), and highlight those variables in the Primary color so the formulas feel personalized.

For the IBW to ABW switch, animate only when crossing the 120% IBW threshold. Use a short `AnimatedSwitcher` transition and display a brief helper line: "Switching to ABW for accuracy". Avoid continuous flicker by not re-triggering the animation while the slider stays on the same side of the threshold."

---

## Implementation Checklist

- [ ] **App Bar:** Verify title, background color, elevation
- [ ] **DetailTextCard:** Confirm padding (16px), border radius (16px), border color
- [ ] **Color Constants:** Map all hex values to AppTheme references
- [ ] **Spacing:** Use AppSpacing constants throughout
- [ ] **Typography:** Verify font sizes and weights match spec
- [ ] **Sliders:** Test min/max ranges and real-time value updates
- [ ] **RichText Highlights:** Confirm formula text styling (bold, primary color)
- [ ] **Buttons:** Test CTA navigation behavior and styling
- [ ] **Responsive Layout:** Test on various screen widths
- [ ] **Accessibility:** Run contrast checker and screen reader validation
- [ ] **Unit System Toggle:** Verify metric/imperial conversions display correctly
- [ ] **Edge Cases:** Test with missing height/weight/gender data

---

## File References

**Source Code Locations:**
- [healthy_range_detail_page.dart](lib/features/analysis/pages/healthy_range_detail_page.dart)
- [weight_formula_detail_page.dart](lib/features/analysis/pages/weight_formula_detail_page.dart)
- [calorie_surplus_detail_page.dart](lib/features/analysis/pages/calorie_surplus_detail_page.dart)
- [abw_formula_simulator.dart](lib/features/analysis/widgets/abw_formula_simulator.dart)
- [energy_balance_snapshot.dart](lib/features/analysis/widgets/energy_balance_snapshot.dart)
- [detail_text_card.dart](lib/features/analysis/widgets/detail_text_card.dart)
- [app_theme.dart](lib/core/theme/app_theme.dart)
- [app_spacing.dart](lib/core/theme/app_spacing.dart)

---

**Document Prepared For:** External UI/UX Designer Handoff  
**Created:** May 14, 2026  
**Last Updated:** May 14, 2026
