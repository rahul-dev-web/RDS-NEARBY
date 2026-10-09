begin;
create index if not exists customer_requests_pending_expiry_idx
  on public.customer_requests (expires_at)
  where status = 'pending'::public.request_status;

create index if not exists notifications_customer_request_due_idx
  on public.notifications (scheduled_at, created_at)
  where status = 'queued'::public.notification_status
    and type in ('customer_request_created', 'customer_request_reminder_3m', 'customer_request_reminder_8m', 'customer_request_response');
commit;