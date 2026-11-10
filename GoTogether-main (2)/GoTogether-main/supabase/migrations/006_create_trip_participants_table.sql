-- Migration: 006_create_trip_participants_table
-- Service B: Trip Hosting
-- Creates the trip_participants table for join requests and tracking

create table trip_participants (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references trips(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  status text check (status in ('pending','approved','rejected')) default 'pending',
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  
  -- Ensure one entry per user per trip
  unique(trip_id, user_id)
);

-- Enable RLS
alter table trip_participants enable row level security;

-- Policy: Users can read their own participation records
create policy "Users can read own participation"
  on trip_participants for select
  using (auth.uid() = user_id);

-- Policy: Host can read participants of their trips
create policy "Host can read trip participants"
  on trip_participants for select
  using (
    exists (
      select 1 from trips
      where trips.id = trip_participants.trip_id
      and trips.host_id = auth.uid()
    )
  );

-- Policy: Approved participants can see other approved participants
create policy "Approved participants can see each other"
  on trip_participants for select
  using (
    status = 'approved'
    and exists (
      select 1 from trip_participants tp2
      where tp2.trip_id = trip_participants.trip_id
      and tp2.user_id = auth.uid()
      and tp2.status = 'approved'
    )
  );

-- Policy: Users can request to join a trip
create policy "Users can request to join"
  on trip_participants for insert
  with check (auth.uid() = user_id);

-- Policy: Host can update participant status (approve/reject)
create policy "Host can manage participants"
  on trip_participants for update
  using (
    exists (
      select 1 from trips
      where trips.id = trip_participants.trip_id
      and trips.host_id = auth.uid()
    )
  );

-- Policy: Users can cancel their own pending request
create policy "Users can cancel own request"
  on trip_participants for delete
  using (auth.uid() = user_id and status = 'pending');

-- Indexes
create index idx_trip_participants_trip_id on trip_participants(trip_id);
create index idx_trip_participants_user_id on trip_participants(user_id);
create index idx_trip_participants_status on trip_participants(status);
