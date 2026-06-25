# ServiciosYa — Estado del proyecto Flutter (al 2026-06-22)

Plataforma multi-servicio del hogar para República Dominicana. App Flutter (web + móvil) con backend en Supabase.

## Stack técnico

- **Framework:** Flutter (Dart SDK >=3.3.0)
- **Backend:** Supabase (`supabase_flutter` ^2.5.0) — Auth, Postgres, Realtime, Storage, Edge Functions
- **Estado:** Riverpod (`flutter_riverpod` + `riverpod_annotation`/`riverpod_generator`)
- **Navegación:** `go_router` ^14.2.0, con redirección por rol y guardas de ruta
- **Notificaciones push:** Firebase Cloud Messaging (`firebase_core`, `firebase_messaging`)
- **Mapas/ubicación:** `google_maps_flutter`, `geolocator`, `geocoding`
- **UI:** `flutter_rating_bar`, `cached_network_image`, `shimmer`, `lottie`, `smooth_page_indicator`, `flutter_svg`, `google_fonts`
- **Otros:** `image_picker`, `permission_handler`, `url_launcher`, `shared_preferences`, `connectivity_plus`, `uuid`, `timeago`

## Estructura de carpetas (`lib/`)

```
lib/
├── app.dart                     # Root widget (MaterialApp.router)
├── main.dart                    # Entry point, init Supabase/Firebase
├── core/
│   ├── config/firebase_options.dart
│   ├── constants/ (app_colors, app_constants)
│   ├── router/app_router.dart   # Todas las rutas de la app
│   ├── theme/app_theme.dart
│   └── services/
│       ├── supabase_service.dart
│       ├── notification_service.dart
│       ├── payment_service.dart
│       ├── pwa_install_service.dart
│       ├── demo_data.dart / demo_provider.dart   # Modo demo sin backend
├── features/
│   ├── auth/            # Login, registro, splash, onboarding, recuperar/cambiar password, verificación de email
│   ├── onboarding_flow/ # Setup inicial cliente/prestador
│   ├── home/            # Home, filtro por categoría, sección de prestadores destacados
│   ├── providers_list/  # Listado y perfil de prestadores
│   ├── booking/         # Solicitud de servicio, búsqueda de prestador, booking, pago, confirmación
│   ├── chat/             # Chat por booking + indicador "escribiendo"
│   ├── notifications/   # Notificaciones in-app
│   ├── provider_dashboard/ # Dashboard del prestador, sus servicios, calificar cliente
│   ├── profile/          # Perfil, historial de bookings (cliente), ayuda
│   ├── safety/            # Términos, reporte de disputas
│   ├── verification/     # Verificación de identidad del prestador
│   └── admin/             # Dashboard de administración
└── shared/                # Modelos y widgets compartidos (botones, inputs, badges, rating stars, etc.)
```

## Rutas principales (`app_router.dart`)

| Ruta | Pantalla | Notas |
|---|---|---|
| `/` | SplashScreen | Maneja su propia navegación inicial |
| `/onboarding`, `/login`, `/register`, `/forgot-password` | Auth | Públicas |
| `/setup-client`, `/setup-provider` | Onboarding flow | Públicas |
| `/verify-email` | EmailVerificationScreen | Pública |
| `/home` | HomeScreen | Solo rol `client` |
| `/dashboard` | ProviderDashboardScreen | Solo rol `provider` |
| `/admin` | AdminDashboardScreen | |
| `/providers`, `/provider/:id`, `/search` | Listado/perfil de prestadores | |
| `/category-filter`, `/service-request` | Flujo de solicitud de servicio | |
| `/searching/:bookingId` | Buscando prestador | |
| `/booking/:providerId`, `/booking-confirmation`, `/bookings` | Flujo de reserva | |
| `/payment`, `/terms`, `/report`, `/rate-client` | Modales (slide-up) | |
| `/profile`, `/change-password`, `/help` | Perfil | |
| `/chat/:bookingId`, `/notifications` | Comunicación | |
| `/verify-identity`, `/my-services` | Dashboard interno del prestador | |

Hay redirección automática según `userRole` (cliente vs prestador) y guardas cruzadas para impedir que un prestador entre a `/home` o un cliente a `/dashboard`. El **modo demo** (`demoModeProvider`) bypassea toda la lógica de auth.

## Backend Supabase

### Edge Functions (`supabase/functions/`)
- `create-payment-intent` — crea intención de pago (Stripe, según `payment_service.dart`)
- `capture-payment` — captura el pago
- `send-booking-email` — email transaccional de reservas
- `send-notification` — push notifications vía FCM

### Esquema base (archivos sueltos en la raíz del repo, anteriores a la carpeta `migrations/`)
- `supabase_schema.sql` (541 líneas) — esquema inicial completo. Tablas: `profiles`, `provider_profiles`, `service_categories`, `provider_services`, `bookings`, `reviews`, `chat_messages`, `verification_requests`, `notifications`, `disputes`, `client_ratings`
- `migration_v2.sql`, `migration_v3.sql`, `migration_v4.sql` — ajustes incrementales posteriores al esquema base
- `VERIFICAR_REALTIME.sql` — script de verificación de configuración Realtime (no es una migración, es una consulta de diagnóstico)

⚠️ Estos archivos viven en la raíz, no en `supabase/migrations/` — no están bajo el control de versiones de Supabase CLI. Si no se aplicaron ya manualmente o vía `migrations/`, deberían consolidarse para evitar desincronización con el proyecto remoto.

### Migraciones (`supabase/migrations/`), en orden cronológico
1. `20260610_chat_schema_fix.sql` — fix de esquema de chat
2. `20260610_device_tokens.sql` — tokens de dispositivo para push
3. `20260611_bookings_dispatch.sql` — despacho de bookings a prestadores
4. `20260611_bookings_negotiation.sql` — negociación de bookings
5. `20260618_email_verification.sql` — verificación de email
6. `20260619_fix_dispatch_accept_and_notify.sql` — fix de aceptación de dispatch + notificación
7. `20260619_fix_realtime_rls.sql` — fix de políticas RLS para Realtime

## Funcionalidades implementadas

- **Autenticación** con Supabase Auth (login, registro con rol cliente/prestador, recuperación y cambio de contraseña, verificación de email)
- **Onboarding diferenciado** para cliente y prestador
- **Búsqueda y filtrado de prestadores** por categoría
- **Flujo completo de reserva**: solicitud de servicio → búsqueda de prestador (dispatch) → confirmación → pago → calificación
- **Pagos** integrados (Stripe vía Edge Functions, pantalla `PaymentScreen`)
- **Chat en tiempo real** por booking, con indicador de "escribiendo"
- **Notificaciones push** (FCM) y notificaciones in-app
- **Dashboard de prestador**: gestión de servicios propios, calificación de clientes
- **Verificación de identidad** del prestador
- **Seguridad/disputas**: pantalla de términos y reporte de disputas
- **Panel de administración**
- **Modo demo** para probar la app sin backend real
- **PWA**: banner de instalación para versión web (`pwa_install_service.dart`, `pwa_install_banner.dart`)

## Otros archivos relevantes en la raíz

- **Notas/documentación de trabajo** (markdown sueltos, no son docs formales sino bitácoras de sesiones de debugging):
  - `CAMBIOS_REALIZADOS.md` — changelog manual de fixes (back buttons, preguntas de frecuencia, etc.)
  - `ANALISIS_PROBLEMA_REALTIME.md` — diagnóstico del problema de Realtime no llegando al dashboard del prestador (RLS + `REPLICA IDENTITY FULL`)
  - `EXECUTE_RLS_MIGRATION.md` — instrucciones + SQL para ejecutar manualmente en el SQL Editor de Supabase Dashboard
  - `OPTIMIZACIONES_CHAT.md` — plan de mejoras de chat estilo WhatsApp (indicador "escribiendo", estados de lectura ✓/✓✓)
  - `README.md`, `SETUP.md` — documentación base del proyecto
- **`.env`** — variables de entorno (Supabase URL/keys, etc.). Está en `.gitignore`, correctamente excluido del repo.
- **`package.json`** — solo contiene `playwright` como devDependency (para testing/automatización del build web), no es un proyecto Node real
- **`serve.js`** — servidor simple para servir el build web localmente
- **`serviciosya.zip`** — archivo comprimido en la raíz (revisar si es un backup viejo que debería eliminarse del repo)
- **`assets/`** — `logo.svg`, animaciones Lottie (`home_service.json`, `shield_security.json`, `team_verified.json`), carpeta `icons/` vacía
- **`web/`** — configuración PWA: `manifest.json`, `firebase-messaging-sw.js` (service worker para push en web), iconos, `favicon.png`
- **Logs/artefactos de build** (`flutter_01.log`, `hs_err_pid13836.log`, carpeta `build/`) — no son parte del código fuente, son generados

## Pendientes / known issues

- `google_fonts` intenta descargar tipografías desde `fonts.gstatic.com` en tiempo de ejecución; si no hay acceso a esa CDN (ej. red restringida), la app cae a fuentes por defecto sin romperse. Pendiente: empaquetar las fuentes localmente como assets si se quiere eliminar la dependencia de red.
- MCP de Supabase para Claude Desktop quedó pendiente de configurar (falta Personal Access Token del usuario).
