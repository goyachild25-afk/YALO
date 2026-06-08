-- ============================================================
-- ServiciosYa - Esquema de base de datos Supabase
-- Ejecuta este SQL en el SQL Editor de tu proyecto Supabase
-- ============================================================

-- Habilitar extensión para UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLA: profiles (usuarios - clientes y prestadores)
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL CHECK (role IN ('client', 'provider')) DEFAULT 'client',
  province TEXT,
  city TEXT,
  address TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: provider_profiles (perfil extendido del prestador)
-- ============================================================
CREATE TABLE IF NOT EXISTS provider_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  full_name TEXT NOT NULL,
  bio TEXT DEFAULT '',
  avatar_url TEXT,
  rating NUMERIC(3,2) DEFAULT 0.00,
  review_count INTEGER DEFAULT 0,
  completed_jobs INTEGER DEFAULT 0,
  province TEXT NOT NULL,
  city TEXT NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_available BOOLEAN DEFAULT TRUE,
  is_verified BOOLEAN DEFAULT FALSE,
  photo_urls TEXT[] DEFAULT '{}',
  member_since TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: service_categories (categorías de servicio)
-- ============================================================
CREATE TABLE IF NOT EXISTS service_categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  emoji TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE
);

-- Insertar categorías iniciales (16 categorías)
INSERT INTO service_categories (id, name, description, emoji, sort_order) VALUES
  ('home_cleaning',     'Limpieza del hogar',        'Limpieza general, profunda y organización',     '🏠', 1),
  ('yard_maintenance',  'Mantenimiento de patios',   'Poda, jardines, remoción de maleza',            '🌿', 2),
  ('pet_care',          'Cuidado de mascotas',       'Baño, cepillado, paseo y cuidado',              '🐾', 3),
  ('car_wash',          'Lavado de vehículos',       'Lavado exterior, interior y encerado',          '🚗', 4),
  ('office_cleaning',   'Limpieza de oficinas',      'Oficinas, locales comerciales y más',           '🏢', 5),
  ('moving',            'Mudanzas y carga',          'Apoyo en mudanzas y traslado',                  '📦', 6),
  ('plumbing',          'Plomería básica',           'Reparaciones y mantenimiento',                  '🔧', 7),
  ('electrical',        'Electricidad básica',       'Instalaciones y reparaciones eléctricas',       '⚡', 8),
  ('deep_cleaning',     'Limpieza profunda',         'Desinfección, vapor y limpieza a fondo',        '✨', 9),
  ('pool_cleaning',     'Limpieza de piscinas',      'Mantenimiento y limpieza de piscinas',          '🏊', 10),
  ('painting',          'Pintura',                   'Pintura de interiores, exteriores y acabados',  '🎨', 11),
  ('carpentry',         'Carpintería',               'Reparaciones, instalaciones y muebles',         '🪚', 12),
  ('pest_control',      'Control de plagas',         'Fumigación y eliminación de plagas',            '🪲', 13),
  ('ac_maintenance',    'Mantenimiento A/C',         'Limpieza y servicio de aires acondicionados',   '❄️', 14),
  ('elder_care',        'Cuidado de adultos mayores','Acompañamiento y asistencia a personas mayores', '👴', 15),
  ('babysitting',       'Cuido de niños',            'Niñera y cuido infantil en el hogar',           '👶', 16),
  ('cooking',           'Servicio de cocina',        'Cocinero a domicilio y preparación de comidas', '👨‍🍳', 17)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- TABLA: provider_services (servicios que ofrece cada prestador)
-- ============================================================
CREATE TABLE IF NOT EXISTS provider_services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
  category_id TEXT NOT NULL REFERENCES service_categories(id),
  category_name TEXT NOT NULL,
  pricing_type TEXT NOT NULL CHECK (pricing_type IN ('fixed', 'quote')) DEFAULT 'fixed',
  fixed_price NUMERIC(10,2),
  price_description TEXT,
  form_fields JSONB,  -- JSON array of ServiceFormField
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: bookings (solicitudes / reservas)
-- ============================================================
CREATE TABLE IF NOT EXISTS bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
  client_name TEXT NOT NULL,
  client_avatar_url TEXT,
  provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE SET NULL,
  provider_name TEXT NOT NULL,
  provider_avatar_url TEXT,
  service_id UUID REFERENCES provider_services(id) ON DELETE SET NULL,
  service_name TEXT NOT NULL,
  status TEXT NOT NULL CHECK (
    status IN ('pending','accepted','rejected','in_progress','completed','cancelled')
  ) DEFAULT 'pending',
  payment_status TEXT NOT NULL CHECK (
    payment_status IN ('pending','paid','refunded')
  ) DEFAULT 'pending',
  scheduled_date TIMESTAMPTZ NOT NULL,
  notes TEXT,
  address TEXT NOT NULL,
  agreed_price NUMERIC(10,2),
  form_answers JSONB,
  stripe_payment_intent_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- TABLA: reviews (reseñas de clientes a prestadores)
-- ============================================================
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE SET NULL,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  rating NUMERIC(2,1) NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- FUNCIÓN: actualizar rating del prestador al insertar reseña
-- ============================================================
CREATE OR REPLACE FUNCTION update_provider_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE provider_profiles
  SET
    rating = (
      SELECT ROUND(AVG(rating)::NUMERIC, 2)
      FROM reviews
      WHERE provider_id = NEW.provider_id
    ),
    review_count = (
      SELECT COUNT(*)
      FROM reviews
      WHERE provider_id = NEW.provider_id
    )
  WHERE id = NEW.provider_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_provider_rating
AFTER INSERT OR UPDATE ON reviews
FOR EACH ROW EXECUTE FUNCTION update_provider_rating();

-- ============================================================
-- FUNCIÓN: actualizar completed_jobs del prestador
-- ============================================================
CREATE OR REPLACE FUNCTION update_provider_completed_jobs()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    UPDATE provider_profiles
    SET completed_jobs = completed_jobs + 1
    WHERE id = NEW.provider_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_completed_jobs
AFTER UPDATE ON bookings
FOR EACH ROW EXECUTE FUNCTION update_provider_completed_jobs();

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE provider_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_categories ENABLE ROW LEVEL SECURITY;

-- Profiles: lectura pública, escritura propia
CREATE POLICY "profiles_select_all" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert_own" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Provider profiles: lectura pública, escritura propia
CREATE POLICY "provider_profiles_select_all" ON provider_profiles FOR SELECT USING (true);
CREATE POLICY "provider_profiles_insert_own" ON provider_profiles FOR INSERT
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "provider_profiles_update_own" ON provider_profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- Provider services: lectura pública, escritura del prestador
CREATE POLICY "provider_services_select_all" ON provider_services FOR SELECT USING (true);
CREATE POLICY "provider_services_insert_own" ON provider_services FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM provider_profiles pp
      WHERE pp.id = provider_id AND pp.user_id = auth.uid()
    )
  );
CREATE POLICY "provider_services_update_own" ON provider_services FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM provider_profiles pp
      WHERE pp.id = provider_id AND pp.user_id = auth.uid()
    )
  );

-- Bookings: cliente ve los suyos, prestador ve los del prestador
CREATE POLICY "bookings_select_client" ON bookings FOR SELECT
  USING (auth.uid() = client_id);
CREATE POLICY "bookings_select_provider" ON bookings FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM provider_profiles pp
      WHERE pp.id = provider_id AND pp.user_id = auth.uid()
    )
  );
CREATE POLICY "bookings_insert_client" ON bookings FOR INSERT
  WITH CHECK (auth.uid() = client_id);
CREATE POLICY "bookings_update_provider" ON bookings FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM provider_profiles pp
      WHERE pp.id = provider_id AND pp.user_id = auth.uid()
    )
  );
CREATE POLICY "bookings_update_client_cancel" ON bookings FOR UPDATE
  USING (auth.uid() = client_id AND status = 'pending');

-- Reviews: lectura pública, escritura del cliente
CREATE POLICY "reviews_select_all" ON reviews FOR SELECT USING (true);
CREATE POLICY "reviews_insert_client" ON reviews FOR INSERT
  WITH CHECK (auth.uid() = client_id);

-- Service categories: lectura pública
CREATE POLICY "service_categories_select_all" ON service_categories FOR SELECT USING (true);

-- ============================================================
-- ÍNDICES para rendimiento
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_provider_profiles_province ON provider_profiles(province);
CREATE INDEX IF NOT EXISTS idx_provider_profiles_city ON provider_profiles(city);
CREATE INDEX IF NOT EXISTS idx_provider_profiles_available ON provider_profiles(is_available);
CREATE INDEX IF NOT EXISTS idx_provider_profiles_rating ON provider_profiles(rating DESC);
CREATE INDEX IF NOT EXISTS idx_provider_services_provider ON provider_services(provider_id);
CREATE INDEX IF NOT EXISTS idx_provider_services_category ON provider_services(category_id);
CREATE INDEX IF NOT EXISTS idx_bookings_client ON bookings(client_id);
CREATE INDEX IF NOT EXISTS idx_bookings_provider ON bookings(provider_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_reviews_provider ON reviews(provider_id);

-- ============================================================
-- TABLA: chat_messages (mensajes de chat por reserva)
-- ============================================================
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  sender_name TEXT NOT NULL,
  content TEXT NOT NULL,
  message_type TEXT NOT NULL CHECK (message_type IN ('text', 'image', 'system')) DEFAULT 'text',
  image_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Sólo los participantes de la reserva pueden leer y escribir
CREATE POLICY "chat_select_participants" ON chat_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_id
        AND (
          b.client_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM provider_profiles pp
            WHERE pp.id = b.provider_id AND pp.user_id = auth.uid()
          )
        )
    )
  );

CREATE POLICY "chat_insert_participants" ON chat_messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM bookings b
      WHERE b.id = booking_id
        AND (
          b.client_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM provider_profiles pp
            WHERE pp.id = b.provider_id AND pp.user_id = auth.uid()
          )
        )
    )
  );

CREATE INDEX IF NOT EXISTS idx_chat_messages_booking ON chat_messages(booking_id, created_at);

-- ============================================================
-- TABLA: verification_requests (solicitudes de verificación)
-- ============================================================
CREATE TABLE IF NOT EXISTS verification_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  full_name TEXT NOT NULL,
  id_number TEXT NOT NULL,
  bio TEXT,
  id_front_url TEXT NOT NULL,
  id_back_url TEXT NOT NULL,
  selfie_url TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
  admin_notes TEXT,
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES profiles(id)
);

ALTER TABLE verification_requests ENABLE ROW LEVEL SECURITY;

-- El prestador sólo puede ver su propia solicitud
CREATE POLICY "verification_select_own" ON verification_requests FOR SELECT
  USING (auth.uid() = user_id);

-- El prestador puede insertar su solicitud
CREATE POLICY "verification_insert_own" ON verification_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Sólo el admin puede actualizar (aprobar/rechazar)
-- Nota: crear un rol 'admin' en auth.users o usar service_role key para el admin panel
CREATE POLICY "verification_update_admin" ON verification_requests FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

CREATE INDEX IF NOT EXISTS idx_verification_status ON verification_requests(status);
CREATE INDEX IF NOT EXISTS idx_verification_user ON verification_requests(user_id);

-- ============================================================
-- TABLA: notifications (notificaciones in-app)
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (
    type IN ('bookingAccepted','bookingRejected','bookingCompleted',
             'newBookingRequest','newReview')
  ),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Cada usuario solo ve sus propias notificaciones
CREATE POLICY "notifications_select_own" ON notifications FOR SELECT
  USING (auth.uid() = user_id);
CREATE POLICY "notifications_update_own" ON notifications FOR UPDATE
  USING (auth.uid() = user_id);
-- Solo el sistema (service role / trigger) puede insertar
CREATE POLICY "notifications_insert_system" ON notifications FOR INSERT
  WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;

-- ============================================================
-- TABLA: disputes (disputas y reportes de seguridad)
-- ============================================================
CREATE TABLE IF NOT EXISTS disputes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  reporter_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reporter_name TEXT NOT NULL,
  reported_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reported_name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (
    type IN ('serviceNotCompleted','fraudOrScam','propertyDamage',
             'inappropriateBehavior','noShow','paymentIssue','other')
  ),
  description TEXT NOT NULL,
  evidence_urls TEXT[] DEFAULT '{}',
  status TEXT NOT NULL CHECK (
    status IN ('open','inReview','resolved','closed')
  ) DEFAULT 'open',
  admin_notes TEXT,
  resolution TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES profiles(id)
);

ALTER TABLE disputes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "disputes_select_own" ON disputes FOR SELECT
  USING (auth.uid() = reporter_id OR auth.uid() = reported_id);
CREATE POLICY "disputes_insert_auth" ON disputes FOR INSERT
  WITH CHECK (auth.uid() = reporter_id);
CREATE POLICY "disputes_update_admin" ON disputes FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));

CREATE INDEX IF NOT EXISTS idx_disputes_status ON disputes(status);
CREATE INDEX IF NOT EXISTS idx_disputes_reporter ON disputes(reporter_id);

-- ============================================================
-- TABLA: client_ratings (prestador califica al cliente)
-- ============================================================
CREATE TABLE IF NOT EXISTS client_ratings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE UNIQUE,
  provider_id UUID NOT NULL REFERENCES provider_profiles(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE client_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "client_ratings_select_provider" ON client_ratings FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM provider_profiles pp
    WHERE pp.id = provider_id AND pp.user_id = auth.uid()
  ));
CREATE POLICY "client_ratings_insert_provider" ON client_ratings FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM provider_profiles pp
    WHERE pp.id = provider_id AND pp.user_id = auth.uid()
  ));

CREATE INDEX IF NOT EXISTS idx_client_ratings_client ON client_ratings(client_id);

-- ============================================================
-- FUNCIÓN: crear notificaciones al cambiar estado de una reserva
-- ============================================================
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

  -- Notificar al PRESTADOR cuando llega una nueva solicitud
  IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
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

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger en UPDATE (cambios de estado)
CREATE TRIGGER trigger_notify_booking_update
AFTER UPDATE ON bookings
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION notify_booking_status_change();

-- Trigger en INSERT (nueva solicitud)
CREATE TRIGGER trigger_notify_booking_insert
AFTER INSERT ON bookings
FOR EACH ROW
EXECUTE FUNCTION notify_booking_status_change();

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================
-- Ejecuta esto también desde el dashboard de Supabase > Storage:
-- Crear buckets:
--   'avatars'           (público) — fotos de perfil
--   'provider-photos'   (público) — fotos del prestador
--   'verification-docs' (privado) — documentos de verificación (cédula + selfie)
