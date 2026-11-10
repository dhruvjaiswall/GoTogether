-- Migration: 011_rate_limiting
-- Service D: System Hardening
-- Rate limiting for anti-gaming protection

create table rate_limits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  action text not null,
  count int default 1,
  window_start timestamp with time zone default now(),
  
  unique(user_id, action)
);

-- Enable RLS
alter table rate_limits enable row level security;

-- Only system can read/write rate limits (via service role)
-- No user-facing policies needed

-- Function to check rate limit
create or replace function check_rate_limit(
  p_user_id uuid,
  p_action text,
  p_max_count int,
  p_window_minutes int
) returns boolean as $$
declare
  v_record record;
  v_window_start timestamp with time zone;
begin
  v_window_start := now() - (p_window_minutes || ' minutes')::interval;
  
  -- Get or create rate limit record
  select * into v_record
  from rate_limits
  where user_id = p_user_id and action = p_action;
  
  if not found then
    -- First action, create record
    insert into rate_limits (user_id, action, count, window_start)
    values (p_user_id, p_action, 1, now());
    return true;
  end if;
  
  -- Check if window has expired
  if v_record.window_start < v_window_start then
    -- Reset window
    update rate_limits
    set count = 1, window_start = now()
    where user_id = p_user_id and action = p_action;
    return true;
  end if;
  
  -- Check if limit exceeded
  if v_record.count >= p_max_count then
    return false;
  end if;
  
  -- Increment count
  update rate_limits
  set count = count + 1
  where user_id = p_user_id and action = p_action;
  
  return true;
end;
$$ language plpgsql security definer;

-- Example rate limits (can be called before actions):
-- check_rate_limit(user_id, 'tag_update', 3, 1440)  -- 3 tag updates per day
-- check_rate_limit(user_id, 'trip_create', 10, 60)  -- 10 trips per hour
-- check_rate_limit(user_id, 'join_request', 20, 60) -- 20 requests per hour
