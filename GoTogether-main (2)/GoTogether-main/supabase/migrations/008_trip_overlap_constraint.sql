-- Migration: 008_trip_overlap_constraint
-- Service B: Trip Hosting
-- Enforces that users cannot join trips with overlapping dates

-- Function: Check for trip date overlap before approving a participant
create or replace function check_trip_overlap()
returns trigger as $$
declare
  new_trip_start date;
  new_trip_end date;
  overlap_count int;
begin
  -- Only check when status is being changed to 'approved'
  if new.status != 'approved' or old.status = 'approved' then
    return new;
  end if;

  -- Get the date range of the trip being joined
  select start_date, end_date into new_trip_start, new_trip_end
  from trips
  where id = new.trip_id;

  -- Check for overlapping approved trips
  select count(*) into overlap_count
  from trip_participants tp
  join trips t on tp.trip_id = t.id
  where tp.user_id = new.user_id
    and tp.status = 'approved'
    and tp.trip_id != new.trip_id  -- Exclude the current trip
    and t.status != 'cancelled'     -- Exclude cancelled trips
    and t.start_date <= new_trip_end
    and t.end_date >= new_trip_start;

  if overlap_count > 0 then
    raise exception 'Cannot approve: User already has an approved trip during these dates (% to %).', new_trip_start, new_trip_end;
  end if;

  return new;
end;
$$ language plpgsql security definer;

-- Trigger: Execute before update when status changes to approved
create trigger on_participant_approval
  before update on trip_participants
  for each row execute procedure check_trip_overlap();

-- Function: Also check overlap when user requests to join (warning only)
-- This is optional - hosts can still see all requests
create or replace function warn_potential_overlap()
returns trigger as $$
declare
  new_trip_start date;
  new_trip_end date;
  overlap_count int;
begin
  -- Get the date range of the trip being requested
  select start_date, end_date into new_trip_start, new_trip_end
  from trips
  where id = new.trip_id;

  -- Check for overlapping approved trips
  select count(*) into overlap_count
  from trip_participants tp
  join trips t on tp.trip_id = t.id
  where tp.user_id = new.user_id
    and tp.status = 'approved'
    and t.status != 'cancelled'
    and t.start_date <= new_trip_end
    and t.end_date >= new_trip_start;

  -- Log warning but allow the request
  if overlap_count > 0 then
    raise notice 'Warning: User has potentially overlapping trips. Host should verify before approval.';
  end if;

  return new;
end;
$$ language plpgsql security definer;

-- Trigger: Check on insert (join request)
create trigger on_join_request
  before insert on trip_participants
  for each row execute procedure warn_potential_overlap();
