-- 0003_device_tokens.sql — APNs device tokens for push notifications.

create type device_platform as enum ('ios');

create table public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  token       text not null unique,          -- APNs device token
  platform    device_platform not null default 'ios',
  environment text not null default 'production',  -- 'sandbox' | 'production'
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index idx_device_tokens_user on public.device_tokens(user_id);
create trigger trg_device_tokens_updated before update on public.device_tokens
  for each row execute function public.set_updated_at();

alter table public.device_tokens enable row level security;

-- A user manages only their own device tokens. The send-push function reads
-- across users via the service role (bypassing RLS).
create policy device_tokens_select on public.device_tokens for select to authenticated
  using ( user_id = auth.uid() );
create policy device_tokens_insert on public.device_tokens for insert to authenticated
  with check ( user_id = auth.uid() );
create policy device_tokens_update on public.device_tokens for update to authenticated
  using ( user_id = auth.uid() ) with check ( user_id = auth.uid() );
create policy device_tokens_delete on public.device_tokens for delete to authenticated
  using ( user_id = auth.uid() );

grant select, insert, update, delete on public.device_tokens to authenticated;
