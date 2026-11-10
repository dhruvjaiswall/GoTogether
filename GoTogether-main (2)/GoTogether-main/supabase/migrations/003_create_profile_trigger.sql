-- Migration: 003_create_profile_trigger
-- Service A: Authentication & User Profile
-- Auto-creates profile when user signs up via Supabase Auth

-- Function: Handle new user signup
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data->>'name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
exception
  when others then
    -- Log error but don't block auth
    raise warning 'Failed to create profile for user %: %', new.id, sqlerrm;
    return new;
end;
$$ language plpgsql security definer;

-- Trigger: Execute on new user creation
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- Function: Update updated_at timestamp on profile changes
create or replace function update_profile_timestamp()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Trigger: Auto-update timestamp on profile update
create trigger on_profile_updated
  before update on profiles
  for each row execute procedure update_profile_timestamp();
