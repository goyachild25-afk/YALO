# ServiciosYa — Compilado completo del proyecto

Documento maestro con el contenido íntegro de toda la documentación, esquema de base de datos y configuración del proyecto. Generado el 2026-06-22.

---

## 1. pubspec.yaml

```yaml
name: servicios_ya
description: ServiciosYa — Plataforma multi-servicio del hogar para República Dominicana.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # Backend
  supabase_flutter: ^2.5.0

  # Push Notifications (Firebase Cloud Messaging)
  firebase_core: ^3.6.0
  firebase_messaging: ^15.1.3

  # State Management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^14.2.0

  # Maps & Location
  google_maps_flutter: ^2.6.0
  geolocator: ^11.0.0
  geocoding: ^3.0.0

  # UI Components
  flutter_rating_bar: ^4.0.1
  cached_network_image: ^3.3.1
  shimmer: ^3.0.0
  lottie: ^3.1.0
  smooth_page_indicator: ^1.1.0
  flutter_svg: ^2.0.10+1

  # Utilities
  intl: ^0.19.0
  image_picker: ^1.1.2
  permission_handler: ^11.3.0
  url_launcher: ^6.3.0
  shared_preferences: ^2.2.3
  connectivity_plus: ^6.0.3
  uuid: ^4.4.0
  timeago: ^3.6.1

  # Fonts
  google_fonts: ^6.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.11
  riverpod_generator: ^2.4.3

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
    - assets/animations/
```

---

## 2. README.md (raíz)

```markdown
# limpieza_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.
```

> Nota: el README quedó con el nombre genérico del scaffold inicial (`limpieza_app`), no se actualizó al renombrar el proyecto a ServiciosYa.

---

## 3. SETUP.md — Guía de configuración

```markdown
# LimpiaYa — Guía de configuración

## 1. Instalar Flutter
1. Descarga Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Extrae en C:\src\flutter
3. Agrega C:\src\flutter\bin al PATH
4. Ejecuta `flutter doctor` para verificar la instalación

## 2. Configurar Supabase
1. Crea una cuenta en https://supabase.com
2. Crea un nuevo proyecto
3. Ve a SQL Editor y pega el contenido de `supabase_schema.sql`, luego ejecútalo
4. Ve a Settings > API y copia:
   - Project URL → reemplaza YOUR_SUPABASE_URL
   - anon public key → reemplaza YOUR_SUPABASE_ANON_KEY
5. Ve a Storage y crea dos buckets públicos:
   - avatars
   - provider-photos

## 3. Configurar claves en la app
Edita lib/core/constants/app_constants.dart:
  supabaseUrl, supabaseAnonKey, googleMapsApiKey, stripePublishableKey

## 4. Configurar Google Maps
Android: AndroidManifest.xml → meta-data com.google.android.geo.API_KEY
iOS: AppDelegate.swift → GMSServices.provideAPIKey(...)

## 5. Instalar dependencias y correr
flutter pub get
flutter run          # o: flutter run -d chrome
flutter build apk --release

## 6. Configurar Stripe (Fase 2)
Cuenta en stripe.com, Publishable Key, Edge Function para procesar pagos en servidor.

## Estructura del proyecto
lib/
├── main.dart
├── app.dart
├── core/{constants,theme,router,services}
└── features/{auth,home,providers_list,booking,provider_dashboard,profile}

## Flujo de usuarios
Cliente: Splash → Onboarding → Registro/Login → Home → Categoría → Lista prestadores →
         Perfil prestador → Solicitar servicio → Confirmación → Ver servicios → Calificar
Prestador: Registro como "prestador" → Panel con solicitudes → Aceptar/Rechazar →
           Gestionar disponibilidad → Ver ingresos y estadísticas
```

---

## 4. Esquema de base de datos — `supabase_schema.sql` (esquema base, 541 líneas)

Ejecutado en el SQL Editor de Supabase. Define el modelo de datos completo inicial.

### Tablas creadas
- **`profiles`** — usuarios (clientes y prestadores): id (= auth.users.id), email, full_name, phone, avatar_url, role (client/provider), province, city, address, is_verified, is_active
- **`provider_profiles`** — perfil extendido del prestador: user_id (FK→profiles), bio, rating, review_count, completed_jobs, province, city, lat/lng, is_available, is_verified, photo_urls[], member_since
- **`service_categories`** — catálogo de categorías (TEXT PK). Insertadas 17 categorías iniciales: home_cleaning, yard_maintenance, pet_care, car_wash, office_cleaning, moving, plumbing, electrical, deep_cleaning, pool_cleaning, painting, carpentry, pest_control, ac_maintenance, elder_care, babysitting, cooking
- **`provider_services`** — servicios que ofrece cada prestador: provider_id, category_id, pricing_type (fixed/quote), fixed_price, form_fields (JSONB)
- **`bookings`** — reservas/solicitudes: client_id, provider_id, service_id, status (pending/accepted/rejected/in_progress/completed/cancelled), payment_status (pending/paid/refunded), scheduled_date, address, agreed_price, form_answers (JSONB), stripe_payment_intent_id
- **`reviews`** — reseñas del cliente al prestador: provider_id, client_id, booking_id, rating (1-5), comment
- **`chat_messages`** — mensajes por reserva: booking_id, sender_id, content, type (text/image/system/offer/counter_offer/offer_accepted/offer_rejected), is_read, image_url
- **`verification_requests`** — verificación de identidad: user_id, id_number, id_front_url, id_back_url, selfie_url, status (pending/approved/rejected), admin_notes
- **`notifications`** — notificaciones in-app: user_id, type (bookingAccepted/bookingRejected/bookingCompleted/newBookingRequest/newReview), title, body, booking_id, is_read
- **`disputes`** — reportes/disputas de seguridad: booking_id, reporter_id, reported_id, type (serviceNotCompleted/fraudOrScam/propertyDamage/inappropriateBehavior/noShow/paymentIssue/other), status (open/inReview/resolved/closed)
- **`client_ratings`** — el prestador califica al cliente: booking_id (unique), provider_id, client_id, rating (1-5)

### Funciones / triggers
- `update_provider_rating()` — recalcula `rating` y `review_count` de `provider_profiles` al insertar/actualizar `reviews`
- `update_provider_completed_jobs()` — incrementa `completed_jobs` cuando `bookings.status` pasa a `completed`
- `notify_booking_status_change()` (SECURITY DEFINER) — inserta en `notifications`:
  - cliente notificado en `accepted`, `rejected`, `completed`
  - prestador notificado en `INSERT` con `status='pending'` (versión base — antes de los fixes de dispatch broadcast)
  - triggers: `trigger_notify_booking_update` (AFTER UPDATE, status cambia), `trigger_notify_booking_insert` (AFTER INSERT)

### RLS (Row Level Security)
Habilitado en todas las tablas. Políticas base:
- `profiles`: lectura pública, insert/update solo del propio usuario (`auth.uid() = id`)
- `provider_profiles` / `provider_services`: lectura pública, escritura solo del prestador dueño
- `bookings`: cliente ve los suyos (`client_id = auth.uid()`), prestador ve los suyos vía `provider_profiles.user_id = auth.uid()`; insert solo cliente; update prestador o cliente (cancelar si `pending`)
- `reviews`: lectura pública, insert solo cliente
- `chat_messages`: solo participantes de la reserva (cliente o prestador del booking) pueden leer/escribir
- `verification_requests`: solo el propio prestador lee/inserta; solo `role='admin'` puede actualizar
- `notifications`: cada usuario solo ve/actualiza las suyas; insert abierto (`true`, pensado para triggers/service role)
- `disputes`: solo reporter/reported leen; insert solo reporter; update solo admin
- `client_ratings`: solo el prestador dueño lee/inserta

### Índices
`provider_profiles` (province, city, is_available, rating DESC), `provider_services` (provider_id, category_id), `bookings` (client_id, provider_id, status), `reviews` (provider_id), `chat_messages` (booking_id, created_at), `verification_requests` (status, user_id), `notifications` (user_id+created_at, user_id+is_read parcial), `disputes` (status, reporter_id), `client_ratings` (client_id)

### Storage buckets (a crear manualmente en Supabase Dashboard)
- `avatars` (público)
- `provider-photos` (público)
- `verification-docs` (privado)

---

## 5. migration_v2.sql (2026-06-09)

```sql
-- CAMBIO 1: provider_profiles.onboarding_answers (JSONB) — respuestas del
-- cuestionario de habilitación de categorías, formato:
--   {"home_cleaning": {"experiencia": true, "equipos": false, "enabled": false}, ...}

-- CAMBIO 3: Sistema de negociación de precios en bookings
--   negotiation_status: no_offer → offer_sent → (agreed | counter_offer_sent) → agreed
--   provider_offer NUMERIC(12,2)        -- oferta del prestador en RD$
--   client_counter_offer NUMERIC(12,2)  -- contraoferta del cliente (máx. una vez)
--   offer_description TEXT
--   service_description TEXT
--   service_photos JSONB DEFAULT '[]'   -- URLs de fotos del trabajo

-- Migración de datos: bookings completed/in_progress/accepted con agreed_price
-- ya seteado se marcan retroactivamente como negotiation_status = 'agreed'

-- Índices: idx_bookings_negotiation_status, idx_bookings_provider_pending,
--          idx_provider_profiles_onboarding_gin (GIN sobre JSONB)
```

---

## 6. migration_v3.sql — Sincronizar categorías con Flutter

Problema: el schema usa TEXT PKs en `service_categories`, pero Flutter (`kServiceCategories`) tenía slugs que no existían en la tabla, rompiendo la FK `provider_services_category_id_fkey` al guardar el onboarding.

Categorías agregadas (idempotente, `ON CONFLICT DO NOTHING`):
`gardening`, `laundry`, `elderly_care`, `appliance_repair`, `ac_service`, `security`, `other` (categoría especial para "Otro servicio" del onboarding), `car_wash` (reinserción de seguridad), `styling` (v3.1 — barbería/uñas/trenzas a domicilio).

---

## 7. migration_v4.sql — Sistema de escrow (pago en garantía)

Amplía `payment_status` para soportar el flujo de captura manual de Stripe:

```
pending → authorized → released | refunded
```

- `pending`: aún no se ha garantizado el pago
- `authorized`: tarjeta reservada en Stripe (`capture_method=manual`), el prestador puede proceder con confianza
- `paid`: alias legacy / captura inmediata (compatibilidad)
- `released`: captura realizada al completar el servicio
- `refunded`: devuelto al cliente (disputa/cancelación)

Cambia el `CHECK` constraint de `bookings.payment_status` y agrega índice parcial `idx_bookings_payment_authorized` sobre `payment_status = 'authorized'`.

---

## 8. VERIFICAR_REALTIME.sql — Script de diagnóstico

No es una migración — es un script de verificación/reparación para Realtime en `bookings`:
1. Verifica que `bookings` esté en la publicación `supabase_realtime`
2. Verifica las políticas RLS existentes
3. Re-habilita RLS si hace falta
4. Recrea políticas: `authenticated_read_pending`, `client_read_own_bookings`, `provider_accept_booking`, `provider_update_own_bookings`
5. Recuerda ejecutar `ALTER PUBLICATION supabase_realtime ADD TABLE bookings;` si no aparece
6. `ALTER TABLE bookings REPLICA IDENTITY FULL;` — necesario para que Realtime capture todos los cambios

---

## 9. Migraciones versionadas (`supabase/migrations/`)

### 9.1 `20260610_chat_schema_fix.sql`
Arregla `chat_messages` para que coincida con el código Flutter:
- Renombra `message_type` → `type`
- Actualiza el `CHECK` para incluir tipos de negociación (`offer`, `counter_offer`, etc.)
- Agrega `is_read BOOLEAN DEFAULT FALSE`
- Agrega `chat_messages` a la publicación `supabase_realtime` (si existe)

### 9.2 `20260610_device_tokens.sql`
Crea tabla `device_tokens` para tokens FCM de push notifications:
- `user_id`, `token`, `platform` (web/android/ios), `UNIQUE(user_id, token)`
- RLS: cada usuario gestiona sus propios tokens (`FOR ALL`); el service role puede leer todos (para enviar notificaciones)
- Índice por `user_id`

### 9.3 `20260611_bookings_dispatch.sql`
Habilita el modo "broadcast" de solicitudes (sin prestador asignado inicialmente):
- `provider_id` y `provider_name` pasan a ser nullable (antes NOT NULL)
- `provider_avatar_url` nullable
- Nuevas columnas: `category_id`, `client_province`
- Índice parcial `idx_bookings_open_requests` sobre `(status, client_province) WHERE provider_id IS NULL AND status='pending'`
- Políticas RLS: `"View open requests"` (SELECT, prestadores ven bookings sin asignar) y `"Accept open requests"` (UPDATE, permite asignarse `provider_id`)

### 9.4 `20260611_bookings_negotiation.sql`
Duplica/asegura las columnas de negociación de precio en `bookings` (mismo propósito que `migration_v2.sql` pero aplicado vía la carpeta de migraciones formales): `negotiation_status`, `provider_offer`, `client_counter_offer`, `agreed_price`, `offer_description`, `service_description`, `service_photos TEXT[]`, `stripe_payment_intent_id`. Índice `idx_bookings_negotiation_status`.

### 9.5 `20260618_email_verification.sql`
```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false;
```

### 9.6 `20260619_fix_dispatch_accept_and_notify.sql`
Fix de dos problemas:
1. **Re-asegura** las políticas RLS de dispatch (`"View open requests"`, `"Accept open requests"`) por si la migración `20260611_bookings_dispatch.sql` no se aplicó completa.
2. **Corrige el trigger de notificaciones**: antes solo se notificaba a un prestador cuando `NEW.provider_id` ya tenía valor — lo que nunca ocurre en el flujo de solicitudes abiertas (broadcast), así que **nadie recibía notificación**. El fix agrega una rama nueva: cuando `provider_id IS NULL` en el INSERT, notifica a **todos los prestadores elegibles** (que ofrecen esa `category_id`, están `is_available` y están en la misma provincia o la provincia del cliente está vacía).

> ⚠️ **Bug detectado en este archivo (línea 11):** `FOR SELECT TO authenticcated` — typo con doble "c" en `authenticated`. Esto probablemente hace que Postgres falle al crear la política (rol inexistente) o, según la versión, la cree para un rol que no existe y nunca aplique — dejando la política `"View open requests"` sin efecto real para usuarios autenticados. **Pendiente de corregir.**

### 9.7 `20260619_fix_realtime_rls.sql`
Fix para `SubscribeException` de Realtime en móvil:
- `REPLICA IDENTITY FULL` en `bookings`, `profiles`, `provider_profiles`, `provider_services`, `chat_messages`
- Asegura que las 5 tablas estén en `supabase_realtime` (`ALTER PUBLICATION ... ADD TABLE`)
- Re-habilita RLS y crea políticas de lectura abierta para autenticados (`USING (true)`) en las 5 tablas — política bastante permisiva, pensada para destrabar Realtime rápido en producción.

---

## 10. Edge Functions (`supabase/functions/`)

### 10.1 `create-payment-intent` — Crear intención de pago (Stripe, Deno)
- Crea un `PaymentIntent` con `capture_method: "manual"` → **escrow**: la tarjeta queda autorizada pero no se cobra hasta `capture-payment`.
- Modelo de comisión 5% + 5%: el `amount` recibido es `clientTotal = basePrice × 1.05`. `applicationFee = basePrice × 0.10` (5% fee del cliente + 5% fee del prestador, como metadata `platform_fee`).
- CORS abierto (`Access-Control-Allow-Origin: *`).

### 10.2 `capture-payment` — Captura el pago ya autorizado
- Se invoca cuando el prestador marca el servicio como completado.
- 1) `stripe.paymentIntents.capture(payment_intent_id)` — cobra realmente la tarjeta.
- 2) Si tiene éxito, actualiza `bookings.payment_status='released'` y `status='completed'` usando la **service role key** (bypassa RLS).
- Maneja el caso "Stripe cobró pero la DB falló" devolviendo `warning` en vez de error 500, para reconciliación manual posterior.

### 10.3 `send-booking-email` — Email de confirmación de reserva
- Usa **Resend** (`RESEND_API_KEY`, plan gratis 100 emails/día) — variables: `RESEND_API_KEY`, `FROM_EMAIL` (ej. `noreply@serviciosya.app`).
- Busca el email del cliente en `profiles`, genera un HTML con diseño de marca (header degradado teal, número de reserva `#SY-XXXXXXXX`, nota de "pago protegido — no se cobra hasta completar el servicio").
- Deploy: `supabase functions deploy send-booking-email --no-verify-jwt`

### 10.4 `send-notification` — Push notifications vía FCM v1 API
- Variables: `FCM_PROJECT_ID`, `FCM_SERVICE_KEY` (Service Account JSON, base64).
- Implementa el flujo OAuth2 de Google a mano: construye un JWT firmado con `RSASSA-PKCS1-v1_5`/SHA-256 a partir de la private key del service account, lo intercambia por un `access_token` en `oauth2.googleapis.com/token`.
- Busca todos los `device_tokens` del usuario destino, envía un mensaje FCM a cada token (incluye bloque `webpush` con icono y `click_action: FLUTTER_NOTIFICATION_CLICK`).
- Si un token responde `UNREGISTERED`, lo borra automáticamente de `device_tokens`.

---

## 11. Bitácoras de debugging / sesiones de trabajo

### 11.1 CAMBIOS_REALIZADOS.md (2026-06-19)

**Completado:**
1. Botones de regreso arreglados — `pushReplacement()` → `push()` en `service_request_screen.dart`
2. Eliminada pregunta de frecuencia en categorías Limpieza/Jardín/Cocina (`category_filter_model.dart`) — solicitudes más rápidas de crear
3. Botones "Rechazar" (solicitudes pending) y "Cancelar servicio" (aceptadas) en `provider_dashboard_screen.dart`
4. SnackBar verde "¡Nueva solicitud disponible!" cuando llega una solicitud que coincide con el nicho del prestador
5. Mapa del dashboard arreglado — `size: Size.infinite` agregado al `CustomPaint` (no se renderizaba)
6. Realtime habilitado en Supabase Publications para tabla `bookings`
7. Políticas RLS "View open requests" / "Accept open requests" ejecutadas

**Tabla de problemas resueltos:**
| Problema | Causa | Solución |
|---|---|---|
| Botones de regreso atrapados | `pushReplacement()` sin forma de volver | Cambio a `push()` |
| Solicitudes no llegan al instante | Realtime no habilitado | Activado en Publications |
| RLS bloqueaba aceptación | Políticas no ejecutadas | SQL de RLS ejecutado |
| Mapa no se veía | `CustomPaint` sin `size` | Agregado `size: Size.infinite` |
| Pregunta de frecuencia innecesaria | UX lenta | Removida de categorías |
| Sin opción rechazar | Lógica incompleta | Botón con `delete()` |

Archivos modificados: `service_request_screen.dart`, `category_filter_model.dart`, `provider_dashboard_screen.dart`, `category_filter_screen.dart`, + Supabase (RLS + Realtime).

### 11.2 ANALISIS_PROBLEMA_REALTIME.md (2026-06-19)

**El problema:** las solicitudes no llegaban al instante al dashboard del prestador. Causas identificadas:
1. Políticas RLS demasiado restrictivas (aunque correctas, posible problema de timing con Realtime)
2. **Falta de `REPLICA IDENTITY FULL`** en `bookings` — sin esto, Realtime no captura todos los cambios correctamente
3. Posible delay en la suscripción del `.stream()` en `openRequestsProvider`

**Solución aplicada:**
- Limpiar y recrear políticas RLS: `authenticated_read_pending`, `client_read_own_bookings`, `provider_accept_booking`, `provider_update_own_bookings`
- `ALTER TABLE bookings REPLICA IDENTITY FULL;`
- Confirmar `bookings` ON en Database → Publications → supabase_realtime

**Causa raíz identificada:** `REPLICA IDENTITY` no estaba configurado, lo que impedía que Realtime capturara cambios correctamente.

### 11.3 EXECUTE_RLS_MIGRATION.md (2026-06-19)

Instrucciones paso a paso para ejecutar manualmente en `https://supabase.com/dashboard/project/ivexcnunszcqoqzzdlfz/sql/new` el SQL que crea (idempotente, con `DO $$ IF NOT EXISTS $$`) las políticas `"View open requests"` y `"Accept open requests"` sobre `bookings`.

### 11.4 OPTIMIZACIONES_CHAT.md

Plan (checklist, no necesariamente completado) para llevar el chat a paridad con WhatsApp:
- Indicador "Usuario está escribiendo..." con puntos animados
- Estados de lectura ✓ (enviado) / ✓✓ (leído)
- Burbujas más redondeadas (`borderRadius: 18`), mejor espaciado, colores por rol, avatar en mensajes del prestador, timestamp visible
- Input bar con feedback visual, ícono de nota de voz (futuro)
- Sincronización en tiempo real sin delay
- Scroll automático al recibir mensaje

Archivos a modificar: `chat_screen.dart`, `typing_provider.dart` (nuevo — **ya existe** en el código actual), `chat_model.dart` (campo `is_read` — **ya existe** en el esquema).

---

## 12. Estructura del código Flutter (`lib/`) — resumen

```
lib/
├── app.dart                     # Root widget (MaterialApp.router)
├── main.dart                    # Entry point, init Supabase/Firebase
├── core/
│   ├── config/firebase_options.dart
│   ├── constants/ (app_colors, app_constants)
│   ├── router/app_router.dart   # ~30 rutas, redirección por rol
│   ├── theme/app_theme.dart
│   └── services/ (supabase_service, notification_service, payment_service,
│                  pwa_install_service, demo_data, demo_provider)
└── features/
    ├── auth/             # login, registro, splash, onboarding, recuperar/cambiar
    │                       password, verificación de email
    ├── onboarding_flow/  # setup inicial cliente/prestador
    ├── home/             # home, filtro de categoría, prestadores destacados
    ├── providers_list/   # listado y perfil de prestadores
    ├── booking/          # solicitud → búsqueda prestador → booking → pago → confirmación
    ├── chat/             # chat por booking + indicador "escribiendo"
    ├── notifications/    # notificaciones in-app
    ├── provider_dashboard/ # dashboard prestador, sus servicios, calificar cliente
    ├── profile/          # perfil, historial bookings cliente, ayuda
    ├── safety/           # términos, reporte de disputas
    ├── verification/     # verificación de identidad del prestador
    └── admin/            # dashboard de administración
```

Rutas completas, guardas de navegación por rol y detalle de cada pantalla: ver `ESTADO_PROYECTO_FLUTTER.md` (documento complementario, ya generado, con la tabla completa de rutas de `app_router.dart`).

---

## 13. Otros archivos de configuración relevantes

- **`.env`** (gitignored) — variables de entorno (Supabase URL/keys)
- **`package.json`** — solo `playwright` como devDependency (testing/automatización del build web)
- **`serve.js`** — servidor simple para servir el build web localmente
- **`web/manifest.json`, `web/firebase-messaging-sw.js`** — configuración PWA y service worker de push en web
- **`assets/`** — `logo.svg`, animaciones Lottie (`home_service.json`, `shield_security.json`, `team_verified.json`)
- **`supabase/.temp/linked-project.json`** — proyecto Supabase vinculado: `ref: ivexcnunszcqoqzzdlfz`, `name: Serviciosya`
- **`serviciosya.zip`** — archivo comprimido en la raíz, posible backup viejo (pendiente de revisar/eliminar)

---

## 14. Pendientes y problemas conocidos (consolidado)

1. **Bug de typo en RLS**: `20260619_fix_dispatch_accept_and_notify.sql` línea 11 tiene `TO authenticcated` (doble "c") — la política `"View open requests"` probablemente no se está aplicando como se espera. **Necesita corrección y re-deploy.**
2. **Archivos SQL sueltos en la raíz** (`supabase_schema.sql`, `migration_v2/v3/v4.sql`, `VERIFICAR_REALTIME.sql`) no están versionados junto a `supabase/migrations/` — riesgo de desincronización entre lo aplicado manualmente y el historial de migraciones del CLI.
3. **`google_fonts`** intenta descargar tipografías de `fonts.gstatic.com` en runtime; sin acceso a esa CDN, cae a fuentes por defecto (no rompe la app, pero no es ideal). Pendiente: empaquetar fuentes como assets locales.
4. **README.md** sin actualizar — todavía dice "limpieza_app" (nombre del scaffold original).
5. **RLS abierta (`USING (true)`)** en `20260619_fix_realtime_rls.sql` para `bookings`, `profiles`, `provider_profiles`, `provider_services`, `chat_messages` — funcional para destrabar Realtime, pero es más permisiva que las políticas granulares originales; revisar si conviene endurecerla una vez confirmado que Realtime funciona.
6. **MCP de Supabase para Claude Desktop** — quedó pendiente de configurar (falta Personal Access Token del usuario). MCP de filesystem ya configurado y funcionando.
7. **`serviciosya.zip`** en la raíz del repo — confirmar si es necesario mantenerlo versionado.
