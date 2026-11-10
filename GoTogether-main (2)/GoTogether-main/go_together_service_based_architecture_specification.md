# GoTogether — Production-Ready Social Travel App

**Role:** Senior Full‑Stack Architect & Mobile Engineer  
**Stack:** Supabase (Postgres + Auth + Edge Functions), React Native (Expo), Next.js

---

## Core Principles (Non‑Negotiable)
- Modular, service‑based architecture
- Each service independently deployable
- Failure isolation between services
- Cloud‑first (Supabase)
- Clear API boundaries
- Security via RLS, not frontend trust

---

# 🧩 SERVICE A — AUTHENTICATION & USER PROFILE (FOUNDATION)

## A1️⃣ Service Planning

### Responsibilities
- User authentication (Google OAuth + Email/Password)
- User identity management via Supabase Auth
- Creation and ownership of **user profile**
- Store basic profile data
- Initialize and own `trust_score`

### Explicitly NOT Responsible For
- Matching logic
- Trip creation or participation
- Chat, payments, expenses
- ID verification (future service)

### API Boundaries
- Other services may **read** profile & trust score
- No other service may **modify** profile data directly

---

## A2️⃣ Database Schema (Supabase / Postgres)

### 1. auth.users (Supabase Managed)
Used only as identity source.

### 2. profiles
```sql
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  bio text,
  trust_score int default 50,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);
```

### RLS Policies
```sql
alter table profiles enable row level security;

create policy "Users can read own profile"
  on profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on profiles for update
  using (auth.uid() = id);
```

---

## A3️⃣ Backend Logic (Supabase)

### Auto‑Create Profile on Signup (Trigger)
```sql
create function handle_new_user()
returns trigger as $$
begin
  insert into profiles (id, full_name, avatar_url)
  values (new.id, new.raw_user_meta_data->>'name', new.raw_user_meta_data->>'avatar_url');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure handle_new_user();
```

### Authentication
- Google OAuth → Supabase Auth
- Email/Password → Supabase Auth
- Profile auto‑created on success

---

## A4️⃣ Frontend Auth Screens

### Screens
1. Login Screen
2. Signup Screen
3. Profile Setup Screen

### Shared Logic (Supabase Client)
```ts
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
)
```

### Key UX Rules
- Handle loading states
- OAuth failure retry
- Profile completion check post‑login

---

## A5️⃣ Testing & Failure Handling

### Test Cases
- OAuth popup blocked
- Duplicate email signup
- Trigger failure (profile missing)
- Network disconnect mid‑auth

### Failure Strategy
- Auth failure ≠ app crash
- Retry logic
- Graceful logout

---

# 🧩 SERVICE B — TRIP HOSTING (CREATE & POST TRIPS)

## B1️⃣ Service Planning

### Scope
- Create, edit, delete trips
- Publish trips to feed

### Dependencies
- Requires valid `auth.uid()`
- Reads trust_score from profiles

### Low Trust Handling
- If trust_score < 30 → trip stays in `draft`

---

## B2️⃣ Database Schema

```sql
create table trips (
  id uuid primary key default gen_random_uuid(),
  host_id uuid references profiles(id) on delete set null,
  destination text not null,
  start_date date not null,
  end_date date not null,
  budget int,
  status text check (status in ('draft','active','cancelled')) default 'draft',
  created_at timestamp default now()
);
```

### RLS
```sql
alter table trips enable row level security;

create policy "Read active trips"
  on trips for select
  using (status = 'active');

create policy "Host manages own trips"
  on trips for all
  using (auth.uid() = host_id);
```

---

## B3️⃣ Backend APIs

| Action | Method | Path |
|------|-------|------|
| Create Trip | POST | /trips |
| Edit Trip | PATCH | /trips/:id |
| Fetch Feed | GET | /trips |
| Soft Delete | PATCH | /trips/:id/cancel |

### Rules
- Auth required
- Host‑only mutation

---

## B4️⃣ Frontend Screens

- Host Trip Form
- Trip Feed
- Trip Detail

### UI States
- Loading skeleton
- Empty feed
- Error banners

---

## B5️⃣ Testing

- End date < start date
- Zero / extreme budgets
- Unauthorized edits
- Host deleted

---

# 🧩 SERVICE C — DISCOVERY & MATCHING ENGINE

## C1️⃣ Planning

### Nature
- Stateless computation service
- No DB writes

### Inputs
- user_id

### Outputs
- Ranked trip list with scores

---

## C2️⃣ Matching Algorithm

### Components
- Tag overlap: intersection / union
- Budget score: closeness ratio
- Date overlap: boolean + weight

### Final Score
```
score = (tag * 0.5) + (budget * 0.3) + (date * 0.2)
```

---

## C3️⃣ Edge Function

- Fetch user preferences
- Fetch active trips
- Compute score
- Return sorted list

Fail gracefully if missing data.

---

## C4️⃣ Discovery UI

- Browse trips
- Sort by score
- Filters: destination, date

---

## C5️⃣ Testing

- 100k+ trips
- Missing tags
- No matches

---

# 🧩 SERVICE D — SYSTEM BLUEPRINT & HARDENING

## D1️⃣ Architecture

- Auth Service
- Profile Service
- Trip Service
- Matching Service
- Chat (future)
- Payments (future)

Failure in one does not cascade.

---

## D2️⃣ Security & Trust

### Risks
- Fake accounts
- Trust gaming

### Mitigation
- Rate limits
- Server‑side trust updates

### Future ID Hook
- Separate verification service
- Trust score adjustment only

---

## D3️⃣ Deployment Strategy

### Environments
- dev
- staging
- prod

### Secrets
- Supabase project secrets

### CI/CD
- GitHub Actions
- Edge function auto‑deploy

---

---

# 🔁 ADDITIONS & UPDATES (POST-REVIEW REQUIREMENTS)

This section extends the original design without breaking existing service boundaries.

---

## 🔖 Mandatory Tag Selection on First Login

### Scope
- Part of **Service A — Auth & User Profile**

### Description
- On **first successful login only**, user must select preference tags before app access
- Examples:
  - party
  - religious
  - adventurous
  - trekking
  - alcoholic
  - gender preferences

### Data Model Addition
```sql
create table user_tags (
  user_id uuid references profiles(id) on delete cascade,
  tag text,
  created_at timestamp default now(),
  primary key (user_id, tag)
);
```

### Rules
- Mandatory on first login
- Editable later, but limited frequency (anti-gaming)

---

## ⭐ Trust Score Lifecycle

### Initial State
- All fresh users start with:
```
trust_score = 50
```

### Trust Score Mutations (Server-Side Only)
- Post-trip feedback
- Host approval / rejection signals
- Abuse reports (future)

❗ Trust score **cannot be edited directly by users**

---

## ⛔ Trip Time-Overlap Constraint

### Rule
A user **cannot join two trips whose date ranges overlap**.

### Enforced In
- **Trip Joining Service (future extension of Service B)**

### Logic
- Before join approval:
```
existing_trip.start <= new_trip.end AND
existing_trip.end >= new_trip.start
```

### Failure Handling
- Join request rejected
- Clear error returned to UI

---

## 🎨 Frontend Design Rule (IMPORTANT)

- **No frontend code generation initially**
- First step must be:
  - Generate **visual UI mockups / images** of screens
  - User approval required before implementation

This applies to **all services going forward**.

---

## 💸 FUTURE SERVICE — EXPENSE SPLITTING

### Service Nature
- Independent, isolated service
- Activated only after trip starts

### Scope
- Split expenses among trip members
- Equal / custom splits

### Data Model (Draft)
```sql
expenses (
  id,
  trip_id,
  paid_by,
  amount,
  created_at
)
```

Members list is **derived from approved trip participants only**.

---

## 💬 FUTURE SERVICE — GROUP CHAT

### Behavior
- Auto-created when user is approved into a trip
- Members = approved trip participants + host

### Features
- Real-time messaging
- Entry point to expense splitting

### Isolation
- Chat failure ≠ trip failure
- Expense failure ≠ chat failure

---

## 📝 Post-Trip Feedback & Reviews

### Flow
- After trip completion:
  - Each member reviews teammates
  - Reviews affect trust score

### Rules
- No self-review
- One review per teammate per trip

### Trust Update Formula (Example)
```
new_trust = old_trust + avg_feedback_delta
```

---

✅ **Auth ships first. Others depend on it.**

