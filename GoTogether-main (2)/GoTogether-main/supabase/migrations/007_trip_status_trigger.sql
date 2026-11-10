-- Migration: 007_trip_status_trigger
-- Service B: Trip Hosting
-- Auto-sets trip status based on host's trust_score

-- Function: Set trip status on create based on trust_score
create or replace function set_trip_status_on_create()
returns trigger as $$
declare
  user_trust int;
begin
  -- Get the host's trust score
  select trust_score into user_trust
  from profiles
  where id = new.host_id;

  -- If trust_score >= 30, auto-publish; otherwise keep as draft
  if user_trust >= 30 then
    new.status := 'active';
  else
    new.status := 'draft';
  end if;

  return new;
end;
$$ language plpgsql security definer;

-- Trigger: Execute before insert on trips
create trigger on_trip_created
  before insert on trips
  for each row execute procedure set_trip_status_on_create();

-- Function: Update updated_at timestamp on trip changes
create or replace function update_trip_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Trigger: Auto-update timestamp on trip update
create trigger on_trip_updated
  before update on trips
  for each row execute procedure update_trip_timestamp();

-- Function: Update updated_at on participant status change
create or replace function update_participant_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Trigger: Auto-update timestamp on participation update
create trigger on_participant_updated
  before update on trip_participants
  for each row execute procedure update_participant_timestamp();
