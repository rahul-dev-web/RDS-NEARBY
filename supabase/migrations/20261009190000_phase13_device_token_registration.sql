-- Phase 13: authenticated device-token registration without exposing service-role credentials.
create or replace function public.register_device_token(
  p_token text,
  p_platform text,
  p_app_version text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;
  if p_token is null or length(trim(p_token)) < 20 or length(p_token) > 4096 then
    raise exception 'invalid_device_token' using errcode = '22023';
  end if;
  if p_platform not in ('android', 'ios', 'web') then
    raise exception 'invalid_device_platform' using errcode = '22023';
  end if;

  insert into public.device_tokens (
    user_id, token, platform, app_version, is_active, last_seen_at
  )
  values (
    v_user_id, trim(p_token), p_platform, nullif(trim(p_app_version), ''), true, now()
  )
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        app_version = excluded.app_version,
        is_active = true,
        last_seen_at = now();
end;
$$;

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;
  if p_token is null or length(trim(p_token)) < 20 or length(p_token) > 4096 then
    raise exception 'invalid_device_token' using errcode = '22023';
  end if;

  update public.device_tokens
  set is_active = false, last_seen_at = now()
  where token = trim(p_token)
    and user_id = auth.uid();
end;
$$;

revoke all on function public.register_device_token(text, text, text) from public, anon;
revoke all on function public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text, text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;
