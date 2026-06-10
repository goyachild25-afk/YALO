-- ============================================================
-- migration_v4.sql — Sistema de escrow (pago en garantía)
--
-- Amplía payment_status para soportar el flujo:
--   pending → authorized → released | refunded
--
--   pending    : aún no se ha garantizado el pago
--   authorized : tarjeta reservada en Stripe (capture_method=manual)
--                el prestador puede proceder con confianza
--   paid       : alias legacy / captura inmediata (mantener compatibilidad)
--   released   : captura realizada al completar el servicio
--   refunded   : devuelto al cliente (disputa / cancelación)
--
-- Ejecutar en: Supabase → SQL Editor → Run
-- Es idempotente.
-- ============================================================

-- ── 1. Ampliar el CHECK de payment_status ───────────────────
ALTER TABLE bookings
  DROP CONSTRAINT IF EXISTS bookings_payment_status_check;

ALTER TABLE bookings
  ADD CONSTRAINT bookings_payment_status_check
  CHECK (payment_status IN ('pending','authorized','paid','released','refunded'));

-- ── 2. Índice para consultas de pagos pendientes de captura ──
CREATE INDEX IF NOT EXISTS idx_bookings_payment_authorized
  ON bookings(payment_status)
  WHERE payment_status = 'authorized';

-- ── 3. Verificar ──────────────────────────────────────────────
-- Resultado esperado: 5 filas con los valores del CHECK
SELECT unnest(ARRAY['pending','authorized','paid','released','refunded']) AS allowed_status;
