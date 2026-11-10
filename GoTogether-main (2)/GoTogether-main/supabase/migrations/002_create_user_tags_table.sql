-- Migration: 002_create_user_tags_table
-- Service A: Authentication & User Profile
-- Creates the user_tags table for mandatory preference selection

create table user_tags (
  user_id uuid references profiles(id) on delete cascade,
  tag text not null,
  created_at timestamp with time zone default now(),
  primary key (user_id, tag)
);

-- Enable RLS
alter table user_tags enable row level security;

-- Policy: Users can read their own tags
create policy "Users can read own tags"
  on user_tags for select
  using (auth.uid() = user_id);

-- Policy: Users can insert their own tags
create policy "Users can insert own tags"
  on user_tags for insert
  with check (auth.uid() = user_id);

-- Policy: Users can delete their own tags (for updating preferences)
create policy "Users can delete own tags"
  on user_tags for delete
  using (auth.uid() = user_id);

-- Policy: Other authenticated users can read tags (for matching algorithm)
create policy "Authenticated users can read all tags"
  on user_tags for select
  using (auth.role() = 'authenticated');

-- Index for faster tag lookups
create index idx_user_tags_user_id on user_tags(user_id);
create index idx_user_tags_tag on user_tags(tag);
