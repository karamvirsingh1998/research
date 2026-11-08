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

-- ===== Replay earlier confessions + reporting (run this part too) =====
create table if not exists public.confession_reports (
  confession_id text not null check (char_length(confession_id) between 6 and 30),
  created_at    timestamptz not null default now()
);
alter table public.confession_reports enable row level security;
drop policy if exists "add reports" on public.confession_reports;
create policy "add reports" on public.confession_reports for insert with check (true);
grant insert on public.confession_reports to anon, authenticated;

-- The ONLY way visitors can read anything: last 24h, text + time + feel count,
-- confessions reported by 2+ people are excluded. Tables stay unreadable.
create or replace function public.recent_confessions(max_rows int default 60)
returns table (id text, text text, created_at timestamptz, feels bigint)
language sql stable security definer set search_path = public as $$
  select c.id, c.text, c.created_at,
         (select count(*) from public.confession_feels f where f.confession_id = c.id) as feels
  from public.confessions c
  where c.created_at > now() - interval '24 hours'
    and (select count(*) from public.confession_reports r where r.confession_id = c.id) < 2
  order by c.created_at desc
  limit least(greatest(max_rows, 1), 150);
$$;
revoke all on function public.recent_confessions(int) from public;
grant execute on function public.recent_confessions(int) to anon, authenticated;
