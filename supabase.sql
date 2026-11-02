-- ELITE : base de données pour messages, adhésions et témoignages
-- À coller dans Supabase > SQL Editor > Run.
-- Ce script peut être relancé sans erreur.

create table if not exists public.submissions (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  type       text not null check (type in ('adhesion','message','temoignage')),
  nom        text not null check (char_length(nom) between 2 and 120),
  email      text check (email is null or char_length(email) <= 200),
  filiere    text check (filiere is null or char_length(filiere) <= 160),
  message    text check (message is null or char_length(message) <= 2000),
  approved   boolean not null default false,   -- témoignage publié sur le site ?
  is_read    boolean not null default false
);

alter table public.submissions enable row level security;

-- Le public peut ENVOYER (jamais lire, jamais s'auto-approuver)
drop policy if exists "public can submit" on public.submissions;
create policy "public can submit" on public.submissions
  for insert to anon
  with check (approved = false and is_read = false);

-- L'administrateur connecté a tous les droits
drop policy if exists "admin full access" on public.submissions;
create policy "admin full access" on public.submissions
  for all to authenticated
  using (true) with check (true);

grant insert on public.submissions to anon;
grant select, update, delete on public.submissions to authenticated;

-- Vue publique : uniquement les témoignages validés, sans e-mail
create or replace view public.testimonials_public as
  select id, nom, filiere, message, created_at
  from public.submissions
  where type = 'temoignage' and approved = true;

grant select on public.testimonials_public to anon, authenticated;


-- =====================================================================
-- STATISTIQUES DE VISITE (anonymes) : à relancer avec le reste du script
-- =====================================================================
create table if not exists public.visits (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  visitor_id text not null check (char_length(visitor_id) between 8 and 64),  -- identifiant aléatoire du navigateur
  device     text not null check (device in ('mobile','tablet','desktop')),
  os         text check (os is null or char_length(os) <= 30),
  browser    text check (browser is null or char_length(browser) <= 30),
  referrer   text check (referrer is null or char_length(referrer) <= 100),
  is_new     boolean not null default true                                     -- première visite de cet appareil
);

create index if not exists visits_created_idx on public.visits (created_at);
create index if not exists visits_visitor_idx on public.visits (visitor_id);

alter table public.visits enable row level security;

drop policy if exists "public can log visit" on public.visits;
create policy "public can log visit" on public.visits
  for insert to anon with check (true);

drop policy if exists "admin reads visits" on public.visits;
create policy "admin reads visits" on public.visits
  for select to authenticated using (true);

grant insert on public.visits to anon;
grant select on public.visits to authenticated;

-- Synthèse calculée côté base (fuseau Africa/Douala), réservée à l'admin connecté
create or replace function public.visit_stats()
returns json
language sql
stable
security invoker
as $$
  select json_build_object(
    'total',        (select count(*) from public.visits),
    'unique',       (select count(distinct visitor_id) from public.visits),
    'returning',    (select count(*) from public.visits where not is_new),
    'today',        (select count(*) from public.visits where created_at >= (date_trunc('day', now() at time zone 'Africa/Douala') at time zone 'Africa/Douala')),
    'today_unique', (select count(distinct visitor_id) from public.visits where created_at >= (date_trunc('day', now() at time zone 'Africa/Douala') at time zone 'Africa/Douala')),
    'week',         (select count(*) from public.visits where created_at >= now() - interval '7 days'),
    'week_unique',  (select count(distinct visitor_id) from public.visits where created_at >= now() - interval '7 days'),
    'month',        (select count(*) from public.visits where created_at >= now() - interval '30 days'),
    'month_unique', (select count(distinct visitor_id) from public.visits where created_at >= now() - interval '30 days'),
    'by_device',    (select coalesce(json_object_agg(k, c), '{}'::json) from (select device k, count(*) c from public.visits group by 1) t),
    'by_os',        (select coalesce(json_object_agg(k, c), '{}'::json) from (select coalesce(os,'Autre') k, count(*) c from public.visits group by 1) t),
    'by_browser',   (select coalesce(json_object_agg(k, c), '{}'::json) from (select coalesce(browser,'Autre') k, count(*) c from public.visits group by 1) t),
    'by_referrer',  (select coalesce(json_object_agg(k, c), '{}'::json) from (select coalesce(referrer,'Direct / inconnu') k, count(*) c from public.visits group by 1 order by 2 desc limit 8) t),
    'freq',         (select json_build_object(
                       '1',    count(*) filter (where c = 1),
                       '2-3',  count(*) filter (where c between 2 and 3),
                       '4-9',  count(*) filter (where c between 4 and 9),
                       '10+',  count(*) filter (where c >= 10))
                     from (select count(*) c from public.visits group by visitor_id) t),
    'by_day',       (select coalesce(json_agg(json_build_object('d', d, 'visits', v, 'uniq', u) order by d), '[]'::json)
                     from (select (created_at at time zone 'Africa/Douala')::date d, count(*) v, count(distinct visitor_id) u
                           from public.visits where created_at >= now() - interval '16 days' group by 1) t)
  );
$$;

revoke all on function public.visit_stats() from public, anon;
grant execute on function public.visit_stats() to authenticated;
