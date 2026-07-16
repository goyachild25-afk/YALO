# YALO — Respaldo maestro del proyecto

> Documento de respaldo integral. Captura **todo lo que YALO es** para poder
> entenderlo, auditarlo o reconstruirlo desde cero. No contiene valores de
> claves secretas (el repo es público); esos viven en Supabase `app_secrets`
> y en un archivo local aparte fuera del repo.

**Snapshot:** 2026-07-09 · commit `eaa9b1b` · 101 archivos Dart · ~33 400 líneas en `lib/`

---

## 1. Identidad

- **Nombre:** YALO
- **Eslogan:** ¿Ya lo resolviste? Con YALO, sí.
- **Qué es:** marketplace de servicios del hogar para República Dominicana
  (limpieza, plomería, electricidad, jardinería, cuidado, mudanzas, etc.),
  que conecta clientes con prestadores verificados.
- **Modelo de ingreso:** comisión 10% por servicio (5% Garantía YALO al
  cliente + 5% Membresía de Visibilidad al prestador).

## 2. Coordenadas de la infraestructura viva

| Recurso | Valor |
|---------|-------|
| Repo GitHub | `goyachild25-afk/YALO` |
| URL producción | https://goyachild25-afk.github.io/YALO/ |
| Supabase project ref | `ivexcnunszcqoqzzdlfz` |
| Supabase URL | `https://ivexcnunszcqoqzzdlfz.supabase.co` |
| Flutter (CI) | 3.32.0 exacto (`C:\Users\JJLA-\flutter_3320\`) |
| Base-href de deploy | `/YALO/` (atado al nombre del repo) |

**Claves de cliente** (no secretas, ya en `lib/core/constants/app_constants.dart`):
Supabase anon key, Google Maps API key, VAPID pública.

**Secretos de servidor** (valores en Supabase `app_secrets` + archivo local de
respaldo, NUNCA en el repo): `vapid_private_key`, `push_hook_secret`,
`didit_api_key`, `didit_webhook_secret`, `didit_workflow_id`.

## 3. Stack

- **Frontend:** Flutter Web (Dart), Riverpod, go_router (URL por hash).
- **Backend:** Supabase — Postgres + RLS, Auth, Realtime, Storage, Edge
  Functions (Deno), pg_cron, pg_net.
- **Hosting/CI:** GitHub Pages + GitHub Actions (verify → build → deploy).

## 4. Estructura del código (`lib/`, 101 archivos)

```
lib/
├── app.dart · main.dart          # raíz (YALOApp) + arranque
├── core/
│   ├── constants/                # app_colors, app_constants
│   ├── router/app_router.dart    # rutas + guardas por rol + puerta de verificación
│   ├── services/                 # 16 servicios (ver abajo)
│   └── utils/                    # cedula_validator, haversine, map_launcher, anti_spam
├── features/                     # 13 módulos (ver abajo)
└── shared/                       # modelos y widgets compartidos
```

**Módulos (`lib/features/`):** admin, auth, booking, chat, home, maintenance,
notifications, onboarding_flow, profile, provider_dashboard, providers_list,
safety, verification.

**Servicios (`lib/core/services/`):** supabase, push (service + stub + web),
pwa_install (service + stub + web), user_location, live_notifications,
payment, accessibility, maintenance, observability, logging, demo_data,
demo_provider.

## 5. Base de datos (17 tablas)

| Tabla | Cols | Propósito |
|-------|------|-----------|
| profiles | 16 | perfil base de todo usuario |
| provider_profiles | 20 | datos del prestador |
| provider_services | 10 | servicios ofrecidos |
| bookings | 33 | reservas |
| chat_messages | 9 | mensajes (text/image/offer/location…) |
| notifications | 8 | avisos in-app |
| verification_requests | 23 | verificación de identidad + resultado Didit |
| push_subscriptions | 8 | suscripciones Web Push |
| disputes | 15 | reportes entre partes |
| reviews / client_ratings | 7 / 7 | reseñas bidireccionales |
| favorites | 3 | prestadores favoritos |
| service_categories | 6 | categorías |
| app_settings | 4 | config editable (comisión, mantenimiento, soporte) |
| app_secrets | 3 | secretos de servidor (RLS deny-all) |
| admin_audit_log | 8 | auditoría de acciones admin |
| analytics_events | 5 | eventos self-hosted |

**Seguridad:** RLS en todas las tablas de usuario; `auth.uid()` envuelto en
`(select auth.uid())`; función `is_admin()` SECURITY DEFINER para acciones
admin.

**Storage (4 buckets):** `avatars` (público), `booking-photos` (público),
`provider-photos` (público), `verification-docs` (**privado**, URLs firmadas).

## 6. Edge Functions desplegadas

| Función | JWT | Propósito |
|---------|-----|-----------|
| notify-new-request | sí | Web Push bidireccional (solicitud nueva / aceptación) |
| didit-create-session | sí | crea sesión de verificación Didit |
| didit-webhook | no | recibe resultado Didit (valida firma HMAC) |
| purge-verification-docs | sí | borra docs de verificación a los 90 días |
| booking-reminders | no | recordatorios de reserva |
| capture-payment | sí | captura de pago (fase pago) |
| export-my-data | sí | Ley 172-13: exportar datos |
| delete-my-account | sí | Ley 172-13: borrar cuenta |
| suspend-user | sí | solo admin: revoca/restaura acceso al suspender/reactivar un usuario |

> Nota: las fuentes de las funciones desplegadas vía panel no están todas en
> el repo. Copias locales parciales en `supabase/functions/`.

## 7. Trabajos programados (pg_cron)

| Job | Frecuencia |
|-----|-----------|
| booking-reminders-every-10-min | `*/10 * * * *` |
| expire-stale-open-requests | `15 * * * *` (cancela pendientes sin prestador >24h) |
| purge-expired-verification-docs | `30 3 * * *` (borra docs KYC >90 días) |

## 8. Integraciones de terceros

- **Didit** (didit.me) — verificación de identidad KYC. App "My Application",
  flujo "Free KYC" (`90e027f5-3f62-493d-844e-69275e360f7d`), webhook →
  `.../functions/v1/didit-webhook`. Gratis hasta 500 verif/mes.
- **Google Maps** — mapas y ubicación (key de cliente en app_constants).
- **Supabase** — backend completo.
- **Resend** — correos transaccionales (send-booking-email, no desplegada aún).

## 9. Despliegue y CI

1. Push a `main` → GitHub Actions.
2. `verify` (analyze + test) → `build` (web release, base-href) → `deploy`
   (GitHub Pages). Falla en verify/build bloquea el deploy.
3. Migraciones de base de datos se aplican directo en Supabase (no pasan por CI).

## 10. Cómo reconstruir desde cero (disaster recovery)

1. Clonar el repo → `flutter pub get`.
2. Restaurar proyecto Supabase (o crear uno nuevo): aplicar el esquema de las
   17 tablas + RLS, recrear buckets, Edge Functions, cron jobs y `app_secrets`
   (valores del archivo local de respaldo).
3. Actualizar `app_constants.dart` con la URL/anon key del proyecto Supabase.
4. Reconfigurar en el panel de Supabase: Auth redirect URLs.
5. Reconfigurar integraciones (Didit workflow + webhook, Google Maps key).
6. `flutter build web --base-href /<repo>/` y desplegar.

## 11. Estado y rumbo

Ver [ESTADO.md](ESTADO.md) (estado vivo detallado) y
[OVERVIEW.en.md](OVERVIEW.en.md) (resumen en inglés).

**Pendiente principal:** pasarela de pago (AZUL/CardNET/Fygaro, bloqueada por
formalización fiscal), YALO Puntos, y dominio propio `yalo.do` (que además
reemplaza la URL `github.io` con el usuario `goyachild25-afk`).
