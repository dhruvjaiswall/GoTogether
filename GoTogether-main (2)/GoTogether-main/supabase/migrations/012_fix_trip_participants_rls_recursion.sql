-- Migration: 012_fix_trip_participants_rls_recursion
-- Fixes infinite recursion in the "Approved participants can see each other" RLS policy.
-- The old policy did a subquery on trip_participants from within its own RLS policy,
-- causing PostgreSQL to re-evaluate the same policy infinitely.
--
-- Fix: Use a SECURITY DEFINER function to bypass RLS for the inner check.

-- Step 1: Create a helper function that bypasses RLS to check participant status
create or replace function is_approved_participant(p_trip_id uuid, p_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from trip_participants
    where trip_id = p_trip_id
    and user_id = p_user_id
    and status = 'approved'
  );
$$;

-- Step 2: Drop the problematic policy
drop policy if exists "Approved participants can see each other" on trip_participants;

-- Step 3: Recreate the policy using the helper function (no more recursion)
create policy "Approved participants can see each other"
  on trip_participants for select
  using (
    status = 'approved'
    and is_approved_participant(trip_id, auth.uid())
  );
