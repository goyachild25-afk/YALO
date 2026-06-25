-- ============================================================
-- Fix: aceptar solicitudes abiertas + notificación de solicitudes broadcast
-- Ejecutar en: Supabase Dashboard → SQL Editor
-- Idempotente — seguro de correr aunque ya se haya aplicado parcialmente.
-- ============================================================

-- ── 1. Re-asegurar las políticas RLS de dispatch (por si la migración
--      20260611_bookings_dispatch.sql no llegó a aplicarse completa) ──────
DROP POLICY IF EXISTS "View open requests" ON bookings;
CREATE POLICY "View open requests" ON bookings
  FOR SELECT TO authenticcated
  USING (provider_id IS NULL AND status = 'pending');

DROP POLICY IF EXISTS "Accept open requests" ON bookings;
CREATE POLICY "Accept open requests" ON bookings
  FOR UPDATE TO authenticated
  USING  (provider_id IS NULL AND status = 'pending')
  WITH CHECK (provider_id IS NOT NULL);

-- ── 2. Notificar a TODOS los prestadores elegibles cuando llega una
--      solicitud broadcast (provider_id NULL). Antes solo se notificaba
--      cuando NEW.provider_id ya tenía un valor, lo que nunca ocurre en
--      el flujo de solicitudes abiertas → nadie recibía notificación. ──
CREATE OR REPLACE FUNCTION notify_booking_status_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Notificar al CLIENTE cuando el prestador cambia el estado
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    INSERT INTO notifications (user_id, type, title, body, booking_id)
    VALUES (
      NEW.client_id,
      'bookingAccepted',
      '✅ Solicitud aceptada',
      NEW.provider_name || ' aceptó tu solicitud de ' || NEW.service_name || '.',
      NEW.id
    );

  ELSIF NEW.status = 'rejected' AND OLD.status = 'pending' THEN
    INSERT INTO notifications (user_id, type, title, body, booking_id)
    VALUES (
      NEW.client_id,
      'bookingRejected',
      'Solicitud rechazada',
      'Tu solicitud de ' || NEW.service_name || ' fue rechazada.',
      NEW.id
    );

  ELSIF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    INSERT INTO notifications (user_id, type, title, body, booking_id)
    VALUES (
      NEW.client_id,
      'bookingCompleted',
      '🎉 Servicio completado',
      'El servicio de ' || NEW.service_name || ' fue completado. ¡Deja tu reseña!',
      NEW.id
    );
  END IF;

  -- Notificar al PRESTADOR cuando llega una nueva solicitud directa
  -- (booking ya creado con un provider_id específico)
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' AND NEW.provider_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, type, title, body, booking_id)
    SELECT
      pp.user_id,
      'newBookingRequest',
      '🔔 Nueva solicitud',
      NEW.client_name || ' solicita ' || NEW.service_name || ' para el ' ||
        TO_CHAR(NEW.scheduled_date AT TIME ZONE 'America/Santo_Domingo', 'DD/MM/YYYY'),
      NEW.id
    FROM provider_profiles pp
    WHERE pp.id = NEW.provider_id;
  END IF;

  -- Notificar a TODOS los prestadores elegibles cuando llega una
  -- solicitud broadcast (sin prestador asignado todavía)
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' AND NEW.provider_id IS NULL THEN
    INSERT INTO notifications (user_id, type, title, body, booking_id)
    SELECT DISTINCT
      pp.user_id,
      'newBookingRequest',
      '🔔 Nueva solicitud cerca de ti',
      NEW.client_name || ' solicita ' || NEW.service_name ||
        CASE WHEN NEW.address IS NOT NULL AND NEW.address != ''
             THEN ' en ' || NEW.address ELSE '' END,
      NEW.id
    FROM provider_services ps
    JOIN provider_profiles pp ON pp.id = ps.provider_id
    WHERE ps.category_id = NEW.category_id
      AND ps.is_active = TRUE
      AND pp.is_available = TRUE
      AND (NEW.client_province IS NULL OR NEW.client_province = ''
           OR pp.province = NEW.client_province);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 3. Verificación ──────────────────────────────────────────────────
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'bookings' ORDER BY policyname;
