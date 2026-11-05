-- MISE À JOUR v4 : dépenses récurrentes
-- À coller dans Supabase > SQL Editor > New query, puis "Run" (relançable sans risque).
-- Ne modifie pas les dépenses existantes.

-- 1) Règles de récurrence (ex. Loyer 950 € tous les mois le 5)
create table if not exists public.recurrences (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  montant        numeric(10,2) not null check (montant > 0),
  categorie_id   uuid not null references public.categories(id) on delete restrict,
  note           text,
  jour           smallint not null check (jour between 1 and 31),
  tous_les_mois  boolean not null default true,
  mois           smallint[] not null default '{}',     -- 1 = janvier … 12 = décembre (si pas tous les mois)
  debut          date not null,                        -- date de la dépense d'origine
  created_at     timestamptz not null default now()
);

revoke all on public.recurrences from anon;
grant select, insert, update, delete on public.recurrences to authenticated;
alter table public.recurrences enable row level security;
drop policy if exists "foyer" on public.recurrences;
create policy "foyer" on public.recurrences
  for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 2) Lien dépense -> récurrence (si la récurrence est arrêtée, les dépenses passées restent)
alter table public.depenses add column if not exists recurrence_id uuid
  references public.recurrences(id) on delete set null;

-- 3) Une seule dépense par récurrence et par mois (évite les doublons entre les deux téléphones)
create unique index if not exists depenses_recurrence_mois
  on public.depenses (recurrence_id, (extract(year from date)::int * 12 + extract(month from date)::int))
  where recurrence_id is not null;

-- 4) Mise à jour en direct
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime'
                 and schemaname = 'public' and tablename = 'recurrences') then
    alter publication supabase_realtime add table public.recurrences;
  end if;
end $$;
