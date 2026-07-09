# Arquitectura

App Flutter Web (compilada con `dart2js`) desplegada en GitHub Pages, con
Supabase como backend completo (auth, base de datos, realtime, storage,
Edge Functions).

## Stack

| Capa | Tecnología |
|------|-----------|
| UI / framework | Flutter 3.32.0 (Dart) |
| Estado | Riverpod (`Provider`, `StreamProvider`, `FutureProvider`, `StateNotifierProvider`) |
| Navegación | `go_router` con estrategia de URL por hash y redirección por rol |
| Backend | Supabase (Postgres + RLS, Auth, Realtime, Storage, Edge Functions, pg_cron, pg_net) |
| Mapas / ubicación | `google_maps_flutter`, `geolocator` |
| Hosting | GitHub Pages (base-href `/Serviciosya/`) |
| CI/CD | GitHub Actions: `verify` → `build` → `deploy` |

## Estructura de `lib/`

```
lib/
├── app.dart                  # Root widget (MaterialApp.router → YALOApp)
├── main.dart                 # Entry point, init Supabase
├── core/
│   ├── constants/            # app_colors (paleta "Brisa Caribeña"), app_constants
│   ├── router/app_router.dart# Todas las rutas + guardas por rol
│   ├── services/             # supabase, push, payment, user_location, live_notifications…
│   └── utils/                # cedula_validator, haversine, map_launcher, anti_spam
├── features/
│   ├── auth/                 # login, registro, verificación email, splash, recuperar clave
│   ├── onboarding_flow/      # setup inicial de cliente y de prestador
│   ├── home/                 # inicio del cliente, categorías, buscador (con voz)
│   ├── providers_list/       # listado y perfil de prestadores
│   ├── booking/              # solicitud inmediata, radar, reserva directa, pago
│   ├── chat/                 # chat por reserva, presencia, negociación, ubicación
│   ├── notifications/        # avisos in-app + banner en vivo
│   ├── provider_dashboard/   # panel del prestador, servicios, calificar cliente
│   ├── profile/              # perfil, reservas del cliente, referidos, ayuda, accesibilidad
│   ├── verification/         # verificación de identidad del prestador (Didit)
│   ├── safety/               # términos, política de privacidad, reporte de disputas
│   └── admin/                # panel de administración (9 pestañas)
└── shared/                   # modelos y widgets compartidos
```

## Navegación y guardas

`app_router.dart` construye el `GoRouter` **una sola vez** por sesión; los
cambios de sesión/rol/mantenimiento solo re-evalúan el `redirect` vía
`refreshListenable` (reconstruirlo entero reseteaba la app al splash).

Guardas clave:
- Rutas públicas vs. protegidas (sin sesión → `/login`).
- Redirección por rol tras login: admin → `/admin`, prestador → `/dashboard`,
  cliente → `/home`.
- **Puerta de verificación:** un prestador sin verificación de identidad
  completada es enviado a `/verify-identity` (ver
  [SEGURIDAD_Y_PRIVACIDAD.md](SEGURIDAD_Y_PRIVACIDAD.md)).
- Modo mantenimiento: bloquea a no-admins cuando el admin activa el toggle
  (se lee en Realtime, sin desplegar).

## Features por rol

**Cliente:** inicio con categorías y buscador (voz donde el navegador lo
soporta), solicitud inmediata ("Ya") con radar en tiempo real, reserva directa
con prestador elegido, "Mis servicios" con acciones por estado, chat con
negociación de precio y compartir ubicación, referidos, favoritos,
accesibilidad, cumplimiento Ley 172-13 (descargar/borrar datos).

**Prestador:** dashboard con estadísticas y niveles (New/Destacado/Experto/
Élite), mapa de actividad en tiempo real, gestión de servicios (precio fijo o
por cotización), toggle de disponibilidad, botón "Cómo llegar".

**Admin:** 9 pestañas — Resumen, Verificaciones, Disputas, Usuarios, Reservas,
Finanzas, Configuración, Analytics, Auditoría.

## Modelo de comisión

Comisión total del 10 % por servicio: 5 % "Garantía YALO" (se añade al
cliente) + 5 % "Membresía de Visibilidad" (se descuenta al prestador).
Definido en `AppConstants.clientFee` / `providerFee`. El cobro automático
(pasarela) es fase siguiente; hoy el pago se coordina directo en efectivo.

## Modo demo

La app incluye un modo demo completo (sin backend) accesible desde el login,
útil para mostrar el producto sin cuenta real.
