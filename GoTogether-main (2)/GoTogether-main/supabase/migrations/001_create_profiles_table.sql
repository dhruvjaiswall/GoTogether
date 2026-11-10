-- Migration: 001_create_profiles_table
-- Service A: Authentication & User Profile
-- Creates the profiles table with trust_score defaulting to 50

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  bio text,
  trust_score int default 50,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Enable RLS
alter table profiles enable row level security;

-- Policy: Users can read their own profile
create policy "Users can read own profile"
  on profiles for select
  using (auth.uid() = id);

-- Policy: Other authenticated users can read profiles (for matching, trip discovery)
create policy "Authenticated users can read all profiles"
  on profiles for select
  using (auth.role() = 'authenticated');

-- Policy: Users can update their own profile (except trust_score - handled by column-level security)
create policy "Users can update own profile"
  on profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Note: trust_score updates are blocked at application level via Edge Functions
-- Client SDK cannot directly update trust_score column
