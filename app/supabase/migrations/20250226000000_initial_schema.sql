-- ============================================================
-- Numia: Initial Schema (baseline from existing Supabase DB)
-- ============================================================
-- This migration captures the existing schema as a baseline.
-- All tables, views, functions, triggers, and RLS policies.
-- ============================================================

-- Extensions
create extension if not exists "uuid-ossp" with schema extensions;

-- ─── TABLES ───────────────────────────────────────────────────

-- 1. Users (profile, linked to auth.users)
create table if not exists public.users (
  id               uuid primary key references auth.users(id) on delete cascade,
  full_name        text not null,
  country          text not null default 'MX',
  birth_date       date,
  occupation       text,
  onboarding_done  boolean not null default false,
  plan             text not null default 'free',
  plan_expires_at  timestamptz,
  avatar_url       text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- 2. Bank Connections (Belvo / Open Banking)
create table if not exists public.bank_connections (
  id                uuid primary key default extensions.uuid_generate_v4(),
  user_id           uuid not null references public.users(id) on delete cascade,
  belvo_link_id     text,
  institution_name  text not null,
  institution_type  text default 'bank',
  connection_type   text not null default 'open_banking',
  status            text not null default 'valid',
  last_sync_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- 3. Accounts (bank accounts, credit cards, wallets)
create table if not exists public.accounts (
  id                uuid primary key default extensions.uuid_generate_v4(),
  user_id           uuid not null references public.users(id) on delete cascade,
  connection_id     uuid references public.bank_connections(id) on delete set null,
  belvo_account_id  text,
  name              text not null,
  type              text,
  currency          text not null default 'MXN',
  balance           numeric not null default 0,
  credit_limit      numeric,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- 4. Transactions
create table if not exists public.transactions (
  id                 uuid primary key default extensions.uuid_generate_v4(),
  user_id            uuid not null references public.users(id) on delete cascade,
  account_id         uuid references public.accounts(id) on delete set null,
  belvo_tx_id        text,
  amount             numeric not null,
  currency           text not null default 'MXN',
  description        text,
  merchant_name      text,
  category           text,
  category_override  text,
  subcategory        text,
  value_date         date not null default current_date,
  is_manual          boolean not null default true,
  notes              text,
  created_at         timestamptz not null default now()
);

-- 5. Goals
create table if not exists public.goals (
  id                    uuid primary key default extensions.uuid_generate_v4(),
  user_id               uuid not null references public.users(id) on delete cascade,
  type                  text not null,
  name                  text not null,
  target_amount         numeric not null,
  current_amount        numeric not null default 0,
  monthly_contribution  numeric,
  target_date           date,
  priority              smallint not null default 1,
  status                text not null default 'active',
  emoji                 text,
  notes                 text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- 6. Debts
create table if not exists public.debts (
  id               uuid primary key default extensions.uuid_generate_v4(),
  user_id          uuid not null references public.users(id) on delete cascade,
  type             text not null,
  name             text not null,
  institution      text,
  total_amount     numeric not null,
  original_amount  numeric,
  monthly_payment  numeric,
  interest_rate    numeric,
  is_active        boolean not null default true,
  notes            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- 7. AI Conversations
create table if not exists public.ai_conversations (
  id                uuid primary key default extensions.uuid_generate_v4(),
  user_id           uuid not null references public.users(id) on delete cascade,
  title             text,
  messages          jsonb not null default '[]'::jsonb,
  context_snapshot  jsonb,
  message_count     integer not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- 8. AI Insights
create table if not exists public.ai_insights (
  id                  uuid primary key default extensions.uuid_generate_v4(),
  user_id             uuid not null references public.users(id) on delete cascade,
  type                text not null,
  content             text not null,
  action_label        text,
  action_route        text,
  is_read             boolean not null default false,
  generated_for_date  date not null default current_date,
  created_at          timestamptz not null default now()
);

-- 9. Subscriptions
create table if not exists public.subscriptions (
  id               uuid primary key default extensions.uuid_generate_v4(),
  user_id          uuid not null references public.users(id) on delete cascade,
  plan             text not null,
  status           text not null,
  amount_mxn       numeric not null,
  payment_provider text default 'stripe',
  provider_sub_id  text,
  starts_at        timestamptz not null,
  expires_at       timestamptz not null,
  cancelled_at     timestamptz,
  created_at       timestamptz not null default now()
);

-- ─── INDEXES ──────────────────────────────────────────────────

create index if not exists idx_transactions_user_date on public.transactions(user_id, value_date desc);
create index if not exists idx_transactions_user_category on public.transactions(user_id, category);
create index if not exists idx_goals_user_status on public.goals(user_id, status);
create index if not exists idx_accounts_user on public.accounts(user_id);
create index if not exists idx_debts_user on public.debts(user_id);
create index if not exists idx_ai_conversations_user on public.ai_conversations(user_id);
create index if not exists idx_ai_insights_user_date on public.ai_insights(user_id, generated_for_date desc);

-- ─── VIEWS ────────────────────────────────────────────────────

-- Monthly summary: income, expenses, net per month
create or replace view public.monthly_summary as
select
  t.user_id,
  date_trunc('month', t.value_date) as month,
  coalesce(sum(t.amount) filter (where t.amount > 0), 0) as income,
  coalesce(sum(abs(t.amount)) filter (where t.amount < 0), 0) as expenses,
  coalesce(sum(t.amount), 0) as net,
  count(*)::bigint as tx_count
from public.transactions t
group by t.user_id, date_trunc('month', t.value_date);

-- Current month breakdown by category
create or replace view public.current_month_by_category as
select
  t.user_id,
  coalesce(t.category_override, t.category) as effective_category,
  coalesce(sum(abs(t.amount)), 0) as total,
  count(*)::bigint as tx_count
from public.transactions t
where t.amount < 0
  and t.value_date >= date_trunc('month', current_date)
group by t.user_id, coalesce(t.category_override, t.category);

-- Net worth: total assets minus total debts
create or replace view public.net_worth as
select
  u.id as user_id,
  coalesce(a.total_assets, 0) as total_assets,
  coalesce(d.total_debt, 0) as total_debt,
  coalesce(a.total_assets, 0) - coalesce(d.total_debt, 0) as net_worth
from public.users u
left join (
  select user_id, sum(balance) as total_assets
  from public.accounts
  where is_active = true
  group by user_id
) a on a.user_id = u.id
left join (
  select user_id, sum(total_amount) as total_debt
  from public.debts
  where is_active = true
  group by user_id
) d on d.user_id = u.id;

-- ─── FUNCTIONS ────────────────────────────────────────────────

-- Auto-create user profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', ''));
  return new;
end;
$$ language plpgsql security definer;

-- Trigger on auth.users
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Auto-update updated_at
create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Apply updated_at triggers
drop trigger if exists set_updated_at on public.users;
create trigger set_updated_at before update on public.users
  for each row execute function public.update_updated_at();

drop trigger if exists set_updated_at on public.accounts;
create trigger set_updated_at before update on public.accounts
  for each row execute function public.update_updated_at();

drop trigger if exists set_updated_at on public.bank_connections;
create trigger set_updated_at before update on public.bank_connections
  for each row execute function public.update_updated_at();

drop trigger if exists set_updated_at on public.goals;
create trigger set_updated_at before update on public.goals
  for each row execute function public.update_updated_at();

drop trigger if exists set_updated_at on public.debts;
create trigger set_updated_at before update on public.debts
  for each row execute function public.update_updated_at();

drop trigger if exists set_updated_at on public.ai_conversations;
create trigger set_updated_at before update on public.ai_conversations
  for each row execute function public.update_updated_at();

-- Complete onboarding RPC
create or replace function public.complete_onboarding(
  p_full_name text,
  p_country text default 'MX',
  p_birth_date date default null,
  p_occupation text default null
)
returns void as $$
begin
  update public.users
  set
    full_name = p_full_name,
    country = p_country,
    birth_date = p_birth_date,
    occupation = p_occupation,
    onboarding_done = true,
    updated_at = now()
  where id = auth.uid();
end;
$$ language plpgsql security definer;

-- Dashboard summary RPC
create or replace function public.get_dashboard_summary()
returns json as $$
declare
  result json;
begin
  select json_build_object(
    'net_worth', (
      select json_build_object(
        'total_assets', coalesce(total_assets, 0),
        'total_debt', coalesce(total_debt, 0),
        'net_worth', coalesce(net_worth, 0)
      )
      from public.net_worth
      where user_id = auth.uid()
    ),
    'monthly_summary', (
      select json_build_object(
        'income', coalesce(income, 0),
        'expenses', coalesce(expenses, 0),
        'net', coalesce(net, 0),
        'tx_count', coalesce(tx_count, 0)
      )
      from public.monthly_summary
      where user_id = auth.uid()
        and month = date_trunc('month', current_date)
    ),
    'active_goals', (
      select coalesce(json_agg(json_build_object(
        'id', g.id,
        'name', g.name,
        'target_amount', g.target_amount,
        'current_amount', g.current_amount,
        'emoji', g.emoji
      )), '[]'::json)
      from public.goals g
      where g.user_id = auth.uid() and g.status = 'active'
    ),
    'active_debts', (
      select coalesce(json_agg(json_build_object(
        'id', d.id,
        'name', d.name,
        'total_amount', d.total_amount,
        'monthly_payment', d.monthly_payment
      )), '[]'::json)
      from public.debts d
      where d.user_id = auth.uid() and d.is_active = true
    ),
    'unread_insights', (
      select count(*)
      from public.ai_insights
      where user_id = auth.uid() and is_read = false
    )
  ) into result;

  return result;
end;
$$ language plpgsql security definer;

-- Financial context for AI coach
create or replace function public.get_financial_context(p_user_id uuid)
returns json as $$
declare
  result json;
begin
  select json_build_object(
    'user', (select row_to_json(u) from public.users u where u.id = p_user_id),
    'accounts', (
      select coalesce(json_agg(row_to_json(a)), '[]'::json)
      from public.accounts a
      where a.user_id = p_user_id and a.is_active = true
    ),
    'recent_transactions', (
      select coalesce(json_agg(row_to_json(t)), '[]'::json)
      from (
        select * from public.transactions
        where user_id = p_user_id
        order by value_date desc
        limit 30
      ) t
    ),
    'goals', (
      select coalesce(json_agg(row_to_json(g)), '[]'::json)
      from public.goals g
      where g.user_id = p_user_id and g.status = 'active'
    ),
    'debts', (
      select coalesce(json_agg(row_to_json(d)), '[]'::json)
      from public.debts d
      where d.user_id = p_user_id and d.is_active = true
    ),
    'net_worth', (
      select row_to_json(n) from public.net_worth n where n.user_id = p_user_id
    )
  ) into result;

  return result;
end;
$$ language plpgsql security definer;

-- ─── ROW LEVEL SECURITY ───────────────────────────────────────

alter table public.users enable row level security;
alter table public.accounts enable row level security;
alter table public.transactions enable row level security;
alter table public.goals enable row level security;
alter table public.debts enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_insights enable row level security;
alter table public.bank_connections enable row level security;
alter table public.subscriptions enable row level security;

-- Users: own row only
create policy "users_select_own" on public.users for select using (auth.uid() = id);
create policy "users_update_own" on public.users for update using (auth.uid() = id);

-- Accounts
create policy "accounts_select_own" on public.accounts for select using (auth.uid() = user_id);
create policy "accounts_insert_own" on public.accounts for insert with check (auth.uid() = user_id);
create policy "accounts_update_own" on public.accounts for update using (auth.uid() = user_id);
create policy "accounts_delete_own" on public.accounts for delete using (auth.uid() = user_id);

-- Transactions
create policy "transactions_select_own" on public.transactions for select using (auth.uid() = user_id);
create policy "transactions_insert_own" on public.transactions for insert with check (auth.uid() = user_id);
create policy "transactions_update_own" on public.transactions for update using (auth.uid() = user_id);
create policy "transactions_delete_own" on public.transactions for delete using (auth.uid() = user_id);

-- Goals
create policy "goals_select_own" on public.goals for select using (auth.uid() = user_id);
create policy "goals_insert_own" on public.goals for insert with check (auth.uid() = user_id);
create policy "goals_update_own" on public.goals for update using (auth.uid() = user_id);
create policy "goals_delete_own" on public.goals for delete using (auth.uid() = user_id);

-- Debts
create policy "debts_select_own" on public.debts for select using (auth.uid() = user_id);
create policy "debts_insert_own" on public.debts for insert with check (auth.uid() = user_id);
create policy "debts_update_own" on public.debts for update using (auth.uid() = user_id);
create policy "debts_delete_own" on public.debts for delete using (auth.uid() = user_id);

-- AI Conversations
create policy "ai_conversations_select_own" on public.ai_conversations for select using (auth.uid() = user_id);
create policy "ai_conversations_insert_own" on public.ai_conversations for insert with check (auth.uid() = user_id);
create policy "ai_conversations_update_own" on public.ai_conversations for update using (auth.uid() = user_id);
create policy "ai_conversations_delete_own" on public.ai_conversations for delete using (auth.uid() = user_id);

-- AI Insights
create policy "ai_insights_select_own" on public.ai_insights for select using (auth.uid() = user_id);
create policy "ai_insights_update_own" on public.ai_insights for update using (auth.uid() = user_id);

-- Bank Connections
create policy "bank_connections_select_own" on public.bank_connections for select using (auth.uid() = user_id);
create policy "bank_connections_insert_own" on public.bank_connections for insert with check (auth.uid() = user_id);
create policy "bank_connections_update_own" on public.bank_connections for update using (auth.uid() = user_id);

-- Subscriptions
create policy "subscriptions_select_own" on public.subscriptions for select using (auth.uid() = user_id);
