-- Migration: 009_create_trip_tags_table
-- Service B: Trip Hosting (Revised)
-- Creates trip_tags for include/exclude tag preferences per trip

create table trip_tags (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references trips(id) on delete cascade,
  tag text not null,
  tag_type text check (tag_type in ('include','exclude')) not null,
  created_at timestamp with time zone default now(),
  
  -- Ensure unique tag per trip per type
  unique(trip_id, tag, tag_type)
);

-- Enable RLS
alter table trip_tags enable row level security;

-- Policy: Anyone can read INCLUDE tags (visible on trip cards)
create policy "Anyone can read include tags"
  on trip_tags for select
  using (tag_type = 'include');

-- Policy: Host can read ALL their trip tags (including exclude)
create policy "Host can read own trip tags"
  on trip_tags for select
  using (
    exists (
      select 1 from trips
      where trips.id = trip_tags.trip_id
      and trips.host_id = auth.uid()
    )
  );

-- Policy: Host can insert tags for their trips
create policy "Host can create trip tags"
  on trip_tags for insert
  with check (
    exists (
      select 1 from trips
      where trips.id = trip_tags.trip_id
      and trips.host_id = auth.uid()
    )
  );

-- Policy: Host can update tags for their trips
create policy "Host can update trip tags"
  on trip_tags for update
  using (
    exists (
      select 1 from trips
      where trips.id = trip_tags.trip_id
      and trips.host_id = auth.uid()
    )
  );

-- Policy: Host can delete tags for their trips
create policy "Host can delete trip tags"
  on trip_tags for delete
  using (
    exists (
      select 1 from trips
      where trips.id = trip_tags.trip_id
      and trips.host_id = auth.uid()
    )
  );

-- Index for faster lookups
create index idx_trip_tags_trip_id on trip_tags(trip_id);
create index idx_trip_tags_type on trip_tags(tag_type);

-- Add constraint: max 3 include tags per trip (enforced via trigger)
create or replace function check_max_include_tags()
returns trigger as $$
declare
  include_count int;
begin
  if new.tag_type = 'include' then
    select count(*) into include_count
    from trip_tags
    where trip_id = new.trip_id and tag_type = 'include';
    
    if include_count >= 3 then
      raise exception 'Maximum 3 include tags allowed per trip.';
    end if;
  end if;
  
  return new;
end;
$$ language plpgsql;

create trigger enforce_max_include_tags
  before insert on trip_tags
  for each row execute procedure check_max_include_tags();
