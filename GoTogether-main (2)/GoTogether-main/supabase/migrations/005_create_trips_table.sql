-- Migration: 005_create_trips_table
-- Service B: Trip Hosting
-- Creates the trips table with status-based visibility

create table trips (
  id uuid primary key default gen_random_uuid(),
  host_id uuid references profiles(id) on delete set null,
  destination text not null,
  start_date date not null,
  end_date date not null,
  budget int,
  description text,
  max_participants int default 10,
  status text check (status in ('draft','active','cancelled')) default 'draft',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  
  -- Constraint: end_date must be >= start_date
  constraint valid_date_range check (end_date >= start_date)
);

-- Enable RLS
alter table trips enable row level security;

-- Policy: Anyone authenticated can read active trips
create policy "Read active trips"
  on trips for select
  using (status = 'active');

-- Policy: Host can read their own trips (any status)
create policy "Host can read own trips"
  on trips for select
  using (auth.uid() = host_id);

-- Policy: Host can insert trips
create policy "Host can create trips"
  on trips for insert
  with check (auth.uid() = host_id);

-- Policy: Host can update own trips
create policy "Host can update own trips"
  on trips for update
  using (auth.uid() = host_id);

-- Policy: Host can delete own trips
create policy "Host can delete own trips"
  on trips for delete
  using (auth.uid() = host_id);

-- Indexes for performance
create index idx_trips_host_id on trips(host_id);
create index idx_trips_status on trips(status);
create index idx_trips_dates on trips(start_date, end_date);
