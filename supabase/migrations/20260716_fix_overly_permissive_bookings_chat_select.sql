-- Misma categoría que profiles (ver migración anterior): políticas SELECT
-- con qual=true que dejaban leer TODO a cualquier usuario autenticado, sin
-- relación con la fila. Ambas tablas ya tenían políticas correctamente
-- acotadas conviviendo al lado — quitar las amplias no reduce ningún acceso
-- legítimo.

-- bookings: cualquier cliente o prestador logueado podía leer TODAS las
-- reservas de TODOS los usuarios (direcciones, GPS, ofertas de
-- negociación). bookings_participant_select ya cubre cliente/prestador/
-- admin; authenticated_read_pending y "View open requests" ya cubren ver
-- solicitudes abiertas sin asignar.
drop policy if exists "read_bookings_authenticated" on public.bookings;

-- chat_messages: cualquier usuario logueado podía leer TODAS las
-- conversaciones privadas entre cualquier cliente y prestador.
-- chat_participant_select ya cubre a las partes reales de cada reserva.
drop policy if exists "read_chat_messages_authenticated" on public.chat_messages;
