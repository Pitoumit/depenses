-- MISE À JOUR v2 : catégories personnalisables
-- À coller dans Supabase > SQL Editor > New query, puis "Run" (une seule fois).
-- Supabase affichera l'avertissement "destructive operations" : c'est normal,
-- l'ancienne colonne "categorie" (texte) est remplacée par un lien vers la table des catégories.
-- Aucune dépense n'est perdue.

-- 1) Table des catégories
create table if not exists public.categories (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nom         text not null check (length(trim(nom)) between 1 and 40),
  couleur     smallint not null default 0 check (couleur between 0 and 7),
  ordre       int not null default 0,
  created_at  timestamptz not null default now()
);

revoke all on public.categories from anon;
grant select, insert, update, delete on public.categories to authenticated;
alter table public.categories enable row level security;

drop policy if exists "foyer" on public.categories;
create policy "foyer" on public.categories
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 2) Catégories par défaut : Fixe et Courses
insert into public.categories (user_id, nom, couleur, ordre)
select u.id, v.nom, v.couleur, v.ordre
from auth.users u
cross join (values ('Fixe', 0, 0), ('Courses', 1, 1)) as v(nom, couleur, ordre)
where not exists (select 1 from public.categories c where c.user_id = u.id);

-- 3) Lien dépense -> catégorie, et reprise des dépenses déjà saisies
alter table public.depenses add column if not exists categorie_id uuid
  references public.categories(id) on delete restrict;

do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'depenses' and column_name = 'categorie') then

    -- les anciennes catégories encore utilisées sont recréées (tu pourras les supprimer dans l'app)
    insert into public.categories (user_id, nom, couleur, ordre)
    select distinct d.user_id,
           case d.categorie when 'restaurants' then 'Restaurants' when 'divers' then 'Divers' else 'Prêt' end,
           case d.categorie when 'restaurants' then 2 when 'divers' then 3 else 4 end,
           case d.categorie when 'restaurants' then 2 when 'divers' then 3 else 4 end
    from public.depenses d
    where d.categorie in ('restaurants', 'divers', 'pret')
      and not exists (select 1 from public.categories c where c.user_id = d.user_id
                      and c.nom = case d.categorie when 'restaurants' then 'Restaurants' when 'divers' then 'Divers' else 'Prêt' end);

    update public.depenses d set categorie_id = c.id
    from public.categories c
    where c.user_id = d.user_id
      and c.nom = case d.categorie when 'courses' then 'Courses' when 'restaurants' then 'Restaurants'
                                   when 'divers' then 'Divers' else 'Prêt' end;

    alter table public.depenses drop column categorie;
  end if;
end $$;

alter table public.depenses alter column categorie_id set not null;
create index if not exists depenses_categorie on public.depenses (categorie_id);

-- 4) Mise à jour en direct des catégories entre les deux téléphones
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'categories') then
    alter publication supabase_realtime add table public.categories;
  end if;
end $$;
