-- Migración v2: columnas de negociación y pago en la tabla bookings
-- Ejecutar una sola vez en el Supabase Dashboard → SQL Editor

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS negotiation_status TEXT NOT NULL DEFAULT 'no_offer'
    CHECK (negotiation_status IN ('no_offer','offer_sent','counter_offer_sent','agreed','offer_rejected')),
  ADD COLUMN IF NOT EXISTS provider_offer DECIMAL(10,2),
  ADD COLUMN IF NOT EXISTS client_counter_offer DECIMAL(10,2),
  ADD COLUMN IF NOT EXISTS agreed_price DECIMAL(10,2),
  ADD COLUMN IF NOT EXISTS offer_description TEXT,
  ADD COLUMN IF NOT EXISTS service_description TEXT,
  ADD COLUMN IF NOT EXISTS service_photos TEXT[],
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT;

-- Índice para buscar reservas por estado de negociación (dashboard del prestador)
CREATE INDEX IF NOT EXISTS idx_bookings_negotiation_status
  ON bookings (negotiation_status);
