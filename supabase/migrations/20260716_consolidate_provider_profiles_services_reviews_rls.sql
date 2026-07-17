-- Continúa la limpieza de RLS iniciada en bookings/profiles/chat_messages.

-- provider_profiles: 3 políticas SELECT idénticas (qual=true) — la lectura
-- pública es intencional (marketplace), pero no hace falta triplicada.
drop policy if exists "provider_profiles_public_read" on public.provider_profiles;
drop policy if exists "provider_profiles_select_all" on public.provider_profiles;
drop policy if exists "read_provider_profiles_authenticated" on public.provider_profiles;
create policy "provider_profiles_select_public"
on public.provider_profiles for select
to public
using (true);

-- provider_services: 2 políticas SELECT idénticas.
drop policy if exists "provider_services_select_all" on public.provider_services;
drop policy if exists "read_provider_services_authenticated" on public.provider_services;
create policy "provider_services_select_public"
on public.provider_services for select
to public
using (true);

-- provider_services_update_own no tenía WITH CHECK — mismo patrón que en
-- bookings. Verificado: el único UPDATE real del código solo cambia
-- is_active, nunca provider_id.
drop policy if exists "provider_services_update_own" on public.provider_services;
create policy "provider_services_update_own"
on public.provider_services for update
to public
using (
  exists (select 1 from provider_profiles pp
          where pp.id = provider_services.provider_id
          and pp.user_id = (select auth.uid()))
)
with check (
  exists (select 1 from provider_profiles pp
          where pp.id = provider_services.provider_id
          and pp.user_id = (select auth.uid()))
);

-- provider_services no tenía NINGUNA política de DELETE — el .delete() de
-- provider_onboarding_screen.dart (reemplazar servicios al editar
-- onboarding) borraba 0 filas en silencio por deny-by-default de RLS.
create policy "provider_services_delete_own"
on public.provider_services for delete
to public
using (
  exists (select 1 from provider_profiles pp
          where pp.id = provider_services.provider_id
          and pp.user_id = (select auth.uid()))
);

-- reviews: 2 políticas SELECT idénticas (lectura pública intencional).
drop policy if exists "reviews_public_read" on public.reviews;
drop policy if exists "reviews_select_all" on public.reviews;
create policy "reviews_select_public"
on public.reviews for select
to public
using (true);
