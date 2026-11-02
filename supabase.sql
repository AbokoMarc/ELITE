-- ELITE : base de données pour messages, adhésions et témoignages
-- À coller dans Supabase > SQL Editor > Run (une seule fois).

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
create policy "public can submit" on public.submissions
  for insert to anon
  with check (approved = false and is_read = false);

-- L'administrateur connecté a tous les droits
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
