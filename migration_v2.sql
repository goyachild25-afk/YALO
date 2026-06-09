-- ============================================================================
-- ServiciosYa — Migración v2
-- Ejecutar en: Supabase Dashboard → SQL Editor
-- Fecha: 2026-06-09
--
-- Cambios incluidos:
--   • CAMBIO 1 — provider_profiles.onboarding_answers (JSONB)
--   • CAMBIO 2 — Sin cambios de schema (solo lógica de aplicación)
--   • CAMBIO 3 — bookings: columnas para el sistema de negociación de precios
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- CAMBIO 1: Cuestionario de incorporación del prestador
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE provider_profiles
  ADD COLUMN IF NOT EXISTS onboarding_answers JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN provider_profiles.onboarding_answers IS
  'Respuestas del cuestionario de habilitación de categorías.
   Formato por categoría:
   {
     "home_cleaning": {"experiencia": true, "equipos": false, "enabled": false},
     "plumbing":      {"experiencia": true, "herramientas": true, "enabled": true},
     ...
   }';

-- ─────────────────────────────────────────────────────────────────────────────
-- CAMBIO 3: Sistema de negociación de precios en reservas
-- ─────────────────────────────────────────────────────────────────────────────

-- Estado del proceso de negociación
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS negotiation_status TEXT NOT NULL DEFAULT 'no_offer'
    CHECK (negotiation_status IN (
      'no_offer',            -- Reserva creada; el prestador aún no ha enviado oferta
      'offer_sent',          -- Prestador envió oferta de precio al cliente
      'counter_offer_sent',  -- Cliente envió contraoferta (solo se permite una vez)
      'agreed',              -- Precio acordado entre ambas partes
      'offer_rejected'       -- Oferta o contraoferta rechazada
    ));

COMMENT ON COLUMN bookings.negotiation_status IS
  'Estado de la negociación de precio. El flujo normal es:
   no_offer → offer_sent → (agreed | counter_offer_sent) → agreed';

-- Oferta de precio enviada por el prestador
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS provider_offer NUMERIC(12, 2);

COMMENT ON COLUMN bookings.provider_offer IS
  'Precio ofertado por el prestador en RD$. Null hasta que envíe la primera oferta.';

-- Contraoferta enviada por el cliente (máximo una sola vez)
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS client_counter_offer NUMERIC(12, 2);

COMMENT ON COLUMN bookings.client_counter_offer IS
  'Precio de contraoferta del cliente en RD$. Null si no hubo contraoferta.';

-- Descripción de la oferta enviada por el prestador
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS offer_description TEXT;

-- Descripción del servicio vista por el prestador al recibir la orden
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS service_description TEXT;

-- Fotos relacionadas con el trabajo (URLs de Supabase Storage)
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS service_photos JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN bookings.service_photos IS
  'Array de URLs de fotos del trabajo a realizar. Ej: ["https://...foto1.jpg"]';

-- ─────────────────────────────────────────────────────────────────────────────
-- Migración de datos existentes
-- Reservas ya completadas/aceptadas con precio acordado → marcadas como 'agreed'
-- ─────────────────────────────────────────────────────────────────────────────
UPDATE bookings
  SET
    negotiation_status = 'agreed',
    provider_offer     = agreed_price
  WHERE
    status             IN ('completed', 'in_progress', 'accepted')
    AND agreed_price   IS NOT NULL
    AND negotiation_status = 'no_offer';

-- ─────────────────────────────────────────────────────────────────────────────
-- Índices para rendimiento
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_bookings_negotiation_status
  ON bookings (negotiation_status);

CREATE INDEX IF NOT EXISTS idx_bookings_provider_pending
  ON bookings (provider_id, status, negotiation_status);

CREATE INDEX IF NOT EXISTS idx_provider_profiles_onboarding_gin
  ON provider_profiles USING gin (onboarding_answers);

-- ─────────────────────────────────────────────────────────────────────────────
-- Verificación final
-- ─────────────────────────────────────────────────────────────────────────────
SELECT
  table_name,
  column_name,
  data_type,
  column_default
FROM information_schema.columns
WHERE
  table_name IN ('bookings', 'provider_profiles')
  AND column_name IN (
    'negotiation_status', 'provider_offer', 'client_counter_offer',
    'offer_description',  'service_description', 'service_photos',
    'onboarding_answers'
  )
ORDER BY table_name, column_name;

DO $$
BEGIN
  RAISE NOTICE '✅ Migración v2 completada exitosamente.';
  RAISE NOTICE '   bookings: +negotiation_status, +provider_offer, +client_counter_offer, +offer_description, +service_description, +service_photos';
  RAISE NOTICE '   provider_profiles: +onboarding_answers';
END $$;
