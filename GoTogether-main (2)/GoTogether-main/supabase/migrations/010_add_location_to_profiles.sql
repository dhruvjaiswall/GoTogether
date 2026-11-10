-- Migration: 010_add_location_to_profiles
-- Service B: Trip Hosting (Revised)
-- Extends profiles table for location-based matching (Service A extension)

-- Add location fields to profiles
alter table profiles
  add column if not exists country text,
  add column if not exists city text,
  add column if not exists latitude numeric,
  add column if not exists longitude numeric;

-- Note: Location is used for soft matching only (slight score boost)
-- Location MUST NOT block or exclude trips per specification
