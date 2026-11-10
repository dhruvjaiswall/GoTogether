# 🧩 SERVICE B — TRIP HOSTING (REVISED & CONFIRMED)

## 1️⃣ UI CONFIRMATION STATUS

* ✅ UI images / wireframes shared by Antigravity for Service B are APPROVED
* ❌ Do NOT redesign the UI structure
* ❌ Do NOT generate frontend code yet
* ✅ You may proceed assuming the UI layout is final

## 2️⃣ Trip Creation — Include / Exclude Tags (NEW FEATURE)

### Purpose
Allow hosts to influence who joins their trip without exposing sensitive preferences.

### At Trip Creation, Host Can:
* Select up to 3 Include Tags
   * Meaning: "I prefer people like this"
* Enable a toggle:
   * "Exclude certain types of people"
   * When enabled → select Exclude Tags

### Important Rules
* Include & Exclude tags are trip-level preferences
* They are NOT user profile tags
* Ownership:
   * Created in Service B
   * Consumed by Service C (Matching)

## 3️⃣ Tag Visibility Rules (STRICT)

### Include Tags
* ✅ Visible on:
   * Trip cards
   * Trip detail page
* Display as:
   * "Looking for people who enjoy…" (or similar positive wording)

### Exclude Tags
* ❌ MUST NOT be visible anywhere in UI
* ❌ MUST NOT be sent to frontend
* ✅ Used only internally for matching

## 4️⃣ Matching Logic — Behavioral Rules (Service C Impact)

### Include Tags
* Act as a score booster
* Increase match percentage when user tags align

### Exclude Tags
* Act as a hard filter
* If user matches an excluded tag:
   * Matching score = 0
   * Trip not shown to that user

**Users must NEVER know:**
* Which tag caused exclusion
* Why a trip is not visible to them

## 5️⃣ Match Display Rules (UI OUTPUT)

### What Users See
* Match result is shown as a percentage only

**Examples:**
* `92% Match`
* `74% Match`
* `41% Match`

### What Users Must NOT See
* No labels like "Highly matched"
* No explanation of score
* No breakdown of preferences
* No reason for rejection

**This opacity is intentional and required.**

## 6️⃣ Location-Based Matching (NEW INPUT)

### Profile Update (Service A extension)
User profile includes:
* Country (required)
* City (optional)
* Lat/Lng (future)

### Matching Behavior
* Matching compares:
   * `user.location ↔ host.location`
* NOT destination

### Constraints
* Location:
   * MUST NOT block matching
   * MUST NOT exclude trips
   * Only slightly boosts score if close

## 7️⃣ Updated Matching Formula (Conceptual)

**Original:**
```
score = (tag * 0.5) + (budget * 0.3) + (date * 0.2)
```

**Revised (conceptual, weights may be normalized):**
* Tags → highest weight
* Budget → strong
* Date → moderate
* Location → very low

**Location is a soft signal only, never a constraint.**

## 8️⃣ What NOT to Change

* ❌ Do NOT modify Service A
* ❌ Do NOT change trust score rules
* ❌ Do NOT expose matching logic
* ❌ Do NOT redesign services
* ❌ Do NOT introduce frontend logic for matching

## 9️⃣ Next Step Instruction

* Proceed with Service B backend adjustments only
* Update schemas / APIs if required for:
   * Include tags
   * Exclude tags
* STOP after backend plan is ready
* WAIT for confirmation before moving forward
