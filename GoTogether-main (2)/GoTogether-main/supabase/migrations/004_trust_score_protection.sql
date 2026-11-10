-- Migration: 004_trust_score_protection
-- Service A: Authentication & User Profile
-- Additional protection for trust_score column

-- Function: Prevent direct trust_score updates from clients
-- This function will be used by Edge Functions for authorized updates only
create or replace function update_trust_score(
  target_user_id uuid,
  score_delta int,
  reason text
)
returns void as $$
begin
  -- Only allow server-side calls (security definer functions)
  -- This function should be called from Edge Functions only
  
  update profiles
  set trust_score = greatest(0, least(100, trust_score + score_delta)),
      updated_at = now()
  where id = target_user_id;
  
  -- Log the trust score change for audit
  -- Future: insert into trust_score_log table
end;
$$ language plpgsql security definer;

-- Revoke direct execute from public, only service role can call
revoke execute on function update_trust_score from public;
grant execute on function update_trust_score to service_role;

-- Function: Check if user has completed tag selection (first login flow)
create or replace function has_selected_tags(user_id uuid)
returns boolean as $$
declare
  tag_count int;
begin
  select count(*) into tag_count
  from user_tags
  where user_tags.user_id = has_selected_tags.user_id;
  
  return tag_count > 0;
end;
$$ language plpgsql security definer;
