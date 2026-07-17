-- CRÍTICO: profiles tenía 3 políticas SELECT con qual=true (2 de ellas para
-- el rol "public", que incluye la anon key sin autenticar) que dejaban leer
-- la tabla completa de usuarios — nombre, email, teléfono, provincia, rol,
-- is_active — a cualquiera, sin login. Verificado contra el código real de
-- la app: el único acceso legítimo a un perfil ajeno es "cuántos referí"
-- (profiles.referred_by = mi uid), usado en referrals_screen.dart.
drop policy if exists "profiles_select_all" on public.profiles;
drop policy if exists "profiles_select_authenticated" on public.profiles;
drop policy if exists "read_profiles_authenticated" on public.profiles;

create policy "profiles_select_own_or_referred"
on public.profiles for select
to public
using (
  (select auth.uid()) = id
  or (select auth.uid()) = referred_by
);
