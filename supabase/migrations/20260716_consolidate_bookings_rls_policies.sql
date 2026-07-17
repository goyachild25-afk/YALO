-- Limpieza de acumulación histórica de políticas en bookings: 13 políticas
-- (6 SELECT + 6 UPDATE + 1 INSERT) reducidas a 6 (2 SELECT + 3 UPDATE + 1
-- INSERT), cada una con un propósito claro y sin solaparse.

-- SELECT: quitar duplicado exacto y políticas subsumidas por
-- bookings_participant_select (cliente OR prestador OR admin).
drop policy if exists "View open requests" on public.bookings;
drop policy if exists "bookings_client_select" on public.bookings;
drop policy if exists "bookings_provider_select" on public.bookings;

-- UPDATE: bookings_participant_update y bookings_provider_update no tenían
-- WITH CHECK — el USING limitaba qué fila se podía tocar, pero nada
-- limitaba a qué valores nuevos podía cambiar, incluyendo en teoría
-- reasignar client_id/provider_id a otra cuenta. Verificado contra cada
-- .update() real del código: ningún flujo (aceptar, rechazar, cancelar,
-- negociar, propina, admin) cambia esas columnas a través de estas
-- políticas — aceptar usa bookings_provider_accept, que ya tiene su
-- propio WITH CHECK correcto. Se consolida en una sola política con
-- WITH CHECK que espeja el USING; las que quedan redundantes se quitan.
drop policy if exists "bookings_participant_update" on public.bookings;
create policy "bookings_participant_update"
on public.bookings for update
to public
using (
  (select auth.uid()) = client_id
  or (select auth.uid()) in (
    select provider_profiles.user_id from provider_profiles
    where provider_profiles.id = bookings.provider_id
  )
)
with check (
  (select auth.uid()) = client_id
  or (select auth.uid()) in (
    select provider_profiles.user_id from provider_profiles
    where provider_profiles.id = bookings.provider_id
  )
);

drop policy if exists "bookings_client_update_cancel" on public.bookings;
drop policy if exists "bookings_provider_update" on public.bookings;
drop policy if exists "bookings_provider_update_own" on public.bookings;
