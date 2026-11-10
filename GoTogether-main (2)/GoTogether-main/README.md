# GoTogether

A social travel matching app that connects travelers with compatible trip companions.

## Tech Stack

- **Frontend**: React Native (Expo)
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **Auth**: Supabase Auth

---

## Quick Start

### Prerequisites
- Node.js 18+
- npm or yarn
- Supabase account

### 1. Clone & Install
```bash
git clone <repo-url>
cd GoTogether

# Install mobile dependencies
cd mobile
npm install
```

### 2. Supabase Setup

1. Create a new Supabase project
2. Run migrations in order:
   ```bash
   # In Supabase SQL Editor, run each file in supabase/migrations/
   001_create_profiles_table.sql
   002_create_user_tags_table.sql
   003_create_profile_trigger.sql
   004_trust_score_protection.sql
   005_create_trips_table.sql
   006_create_trip_participants_table.sql
   007_trip_status_trigger.sql
   008_trip_overlap_constraint.sql
   009_create_trip_tags_table.sql
   010_add_location_to_profiles.sql
   011_rate_limiting.sql
   ```

3. Deploy Edge Functions:
   ```bash
   supabase functions deploy get-matched-trips
   ```

### 3. Environment Variables

```bash
# Create mobile/.env
cp .env.example mobile/.env
```

Edit `mobile/.env`:
```
EXPO_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
EXPO_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```

### 4. Run the App

```bash
cd mobile
npx expo start
```

---

## Project Structure

```
GoTogether/
├── mobile/                 # React Native app
│   ├── app/               # Expo Router screens
│   ├── lib/               # Supabase client
│   └── .env               # Environment variables
├── supabase/
│   ├── migrations/        # SQL migrations (001-011)
│   └── functions/         # Edge Functions
├── docs/                   # Architecture docs
└── .github/workflows/      # CI/CD
```

---

## Services

| Service | Description |
|---------|-------------|
| **A** | Authentication & User Profiles |
| **B** | Trip Hosting & Participation |
| **C** | Discovery & Matching Engine |
| **D** | Security & Hardening |

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture.

---

## Key Features

- ✅ Email/Password authentication
- ✅ Mandatory tag selection on first login
- ✅ Trip creation with include/exclude tags
- ✅ Personalized match scoring
- ✅ Trip overlap prevention
- ✅ Trust score system

---

## License

MIT
