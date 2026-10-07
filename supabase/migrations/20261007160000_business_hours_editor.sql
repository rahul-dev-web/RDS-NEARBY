-- Phase 3: business hours editor support
-- Safe additive change: existing businesses receive a standard weekly hours payload.
alter table public.businesses
  add column if not exists opening_hours jsonb not null default '{
    "mon": {"open": "09:00", "close": "18:00", "closed": false},
    "tue": {"open": "09:00", "close": "18:00", "closed": false},
    "wed": {"open": "09:00", "close": "18:00", "closed": false},
    "thu": {"open": "09:00", "close": "18:00", "closed": false},
    "fri": {"open": "09:00", "close": "18:00", "closed": false},
    "sat": {"open": "09:00", "close": "18:00", "closed": false},
    "sun": {"open": "09:00", "close": "18:00", "closed": false}
  }'::jsonb;

comment on column public.businesses.opening_hours is
  'Weekly business-hours JSON. Keys mon..sun; each value has open, close (HH:MM) and closed boolean.';
