-- ============================================================
-- migration_v3.sql — Sincronizar service_categories con
--   los IDs usados en kServiceCategories de Flutter
--
-- El schema usa TEXT PKs en service_categories. Flutter tiene
-- algunos slugs que no existen en la tabla, lo que rompe la FK
-- provider_services_category_id_fkey al guardar el onboarding.
--
-- Ejecutar en: Supabase → SQL Editor → Run
-- Es idempotente (ON CONFLICT DO NOTHING).
-- ============================================================

-- ── Categorías que faltan en la BD pero existen en Flutter ──
INSERT INTO service_categories (id, name, description, emoji, sort_order) VALUES
  ('gardening',        'Jardinería',                         'Mantenimiento y cuidado de jardines',             '🌿', 18),
  ('laundry',          'Lavandería',                         'Lavado y planchado de ropa a domicilio',          '👕', 19),
  ('elderly_care',     'Cuidado de adultos mayores',         'Acompañamiento y asistencia a personas mayores',  '👴', 20),
  ('appliance_repair', 'Reparación de electrodomésticos',    'Reparación de lavadoras, neveras, aires y más',   '🔌', 21),
  ('ac_service',       'Aire acondicionado',                 'Instalación, servicio y reparación de A/C',       '❄️', 22),
  ('security',         'Seguridad y vigilancia',             'Guardias de seguridad y vigilancia privada',      '🔒', 23),
  -- Categoría especial para el campo "Otro servicio" del onboarding
  ('other',            'Otro servicio',                      'Servicio personalizado no listado en las categorías estándar', '⭐', 24)
ON CONFLICT (id) DO NOTHING;

-- ── Verificar que todas las categorías de Flutter estén presentes ──
-- (Resultado esperado: 24 filas o más)
SELECT id, name, sort_order
FROM   service_categories
WHERE  id IN (
  'home_cleaning', 'office_cleaning', 'pet_care', 'plumbing',
  'electrical', 'painting', 'carpentry', 'gardening', 'moving',
  'pest_control', 'laundry', 'cooking', 'babysitting', 'elderly_care',
  'appliance_repair', 'ac_service', 'security', 'other'
)
ORDER BY sort_order;
