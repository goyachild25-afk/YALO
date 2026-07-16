-- Habilita Realtime en verification_requests y disputes para que el panel
-- Admin pueda avisar en el momento cuando llega algo nuevo (antes había que
-- tocar "Actualizar datos" manualmente).
--
-- De paso se agrega app_settings: el modo mantenimiento ya usaba
-- onPostgresChanges sobre esta tabla (maintenance_service.dart) asumiendo
-- que estaba en la publicación de Realtime, pero no lo estaba — el valor
-- inicial se leía bien (select directo), pero un toggle en vivo desde otra
-- sesión no se propagaba hasta que esa sesión navegara de nuevo.
alter publication supabase_realtime add table public.verification_requests;
alter publication supabase_realtime add table public.disputes;
alter publication supabase_realtime add table public.app_settings;
