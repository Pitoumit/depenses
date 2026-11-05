-- MISE À JOUR v3 : revenus (Bilan du mois)
-- À coller dans Supabase > SQL Editor > New query, puis "Run" (une seule fois, relançable sans risque).
-- Ne modifie pas les dépenses existantes.

-- 1) Sources de revenus (Salaire Quentin, Salaire Mathilde…)
create table if not exists public.sources_revenu (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nom         text not null check (length(trim(nom)) between 1 and 40),
  couleur     smallint not null default 0 check (couleur between 0 and 7),
  ordre       int not null default 0,
  created_at  timestamptz not null default now()
);

-- 2) Revenus
create table if not exists public.revenus (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date        date not null default current_date,
  montant     numeric(10,2) not null check (montant > 0),
  source_id   uuid not null references public.sources_revenu(id) on delete restrict,
  note        text,
  created_at  timestamptz not null default now()
);
create index if not exists revenus_user_date on public.revenus (user_id, date);
create index if not exists revenus_source on public.revenus (source_id);

-- 3) Sécurité : accès réservé au compte connecté
revoke all on public.sources_revenu from anon;
revoke all on public.revenus from anon;
grant select, insert, update, delete on public.sources_revenu to authenticated;
grant select, insert, update, delete on public.revenus to authenticated;
alter table public.sources_revenu enable row level security;
alter table public.revenus enable row level security;

drop policy if exists "foyer" on public.sources_revenu;
create policy "foyer" on public.sources_revenu
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "foyer" on public.revenus;
create policy "foyer" on public.revenus
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 4) Sources par défaut
insert into public.sources_revenu (user_id, nom, couleur, ordre)
select u.id, v.nom, v.couleur, v.ordre
from auth.users u
cross join (values ('Salaire Quentin', 0, 0), ('Salaire Mathilde', 6, 1)) as v(nom, couleur, ordre)
where not exists (select 1 from public.sources_revenu s where s.user_id = u.id);

-- 5) Mise à jour en direct entre les deux téléphones
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                 and schemaname = 'public' and tablename = 'sources_revenu') then
    alter publication supabase_realtime add table public.sources_revenu;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                 and schemaname = 'public' and tablename = 'revenus') then
    alter publication supabase_realtime add table public.revenus;
  end if;
end $$;
