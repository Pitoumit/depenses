-- MISE À JOUR v5 : 16 couleurs au lieu de 8 pour les catégories et les sources de revenus
-- À coller dans Supabase > SQL Editor > New query, puis "Run" (relançable sans risque).
-- Ne modifie aucune donnée.

alter table public.categories drop constraint if exists categories_couleur_check;
alter table public.categories add constraint categories_couleur_check check (couleur between 0 and 15);

alter table public.sources_revenu drop constraint if exists sources_revenu_couleur_check;
alter table public.sources_revenu add constraint sources_revenu_couleur_check check (couleur between 0 and 15);
