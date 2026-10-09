begin;
revoke all on function public.cancel_customer_request_reminders() from public, anon, authenticated;
commit;