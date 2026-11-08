-- Diwali Confessions: run once in Supabase → SQL Editor → New query → Run
-- Anonymous, insert-only. Visitors can add rows but can never read them back.

create table if not exists public.confessions (
  id         text primary key check (char_length(id) between 6 and 30),
  text       text not null check (char_length(text) between 3 and 140)
             check (text !~* '(https?://|www\.)'),
  prompt     text check (char_length(prompt) <= 80),
  created_at timestamptz not null default now()
);

create table if not exists public.confession_feels (
  confession_id text not null check (char_length(confession_id) between 6 and 30),
  created_at    timestamptz not null default now()
);

alter table public.confessions      enable row level security;
alter table public.confession_feels enable row level security;

drop policy if exists "add confessions" on public.confessions;
drop policy if exists "add feels"       on public.confession_feels;
create policy "add confessions" on public.confessions      for insert with check (true);
create policy "add feels"       on public.confession_feels for insert with check (true);
-- No select policy on purpose: the public can't read stored confessions.

grant insert on public.confessions, public.confession_feels to anon, authenticated;
