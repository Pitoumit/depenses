-- À coller dans Supabase > SQL Editor > New query, puis "Run".

create table if not exists public.depenses (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date        date not null default current_date,
  montant     numeric(10,2) not null check (montant > 0),
  categorie   text not null check (categorie in ('courses','restaurants','divers','pret')),
  note        text,
  created_at  timestamptz not null default now()
);

create index if not exists depenses_user_date on public.depenses (user_id, date);

-- Accès via l'API : uniquement pour un utilisateur connecté, jamais pour un visiteur anonyme
revoke all on public.depenses from anon;
grant select, insert, update, delete on public.depenses to authenticated;

-- Sécurité : seul le compte connecté voit et modifie ses dépenses
alter table public.depenses enable row level security;

drop policy if exists "foyer" on public.depenses;
create policy "foyer" on public.depenses
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Mise à jour en direct entre les deux téléphones
alter publication supabase_realtime add table public.depenses;
