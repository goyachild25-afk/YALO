# Backend (Supabase)

Proyecto Supabase ref: `ivexcnunszcqoqzzdlfz`

La base de datos es la fuente de verdad del esquema; se gestiona con
**migraciones aplicadas directo en Supabase** (no hay scripts SQL sueltos en
el repo — los antiguos `migration_v*.sql` se eliminaron por obsoletos). Este
documento describe la estructura viva.

## Tablas principales

| Tabla | Propósito |
|-------|-----------|
| `profiles` | Perfil base de todo usuario (rol, nombre, contacto, `is_verified`, `referral_code`). Creado por trigger `handle_new_user` al registrarse. |
| `provider_profiles` | Datos del prestador (bio, rating, nivel, disponibilidad, coordenadas, `is_verified`). |
| `provider_services` | Servicios que ofrece cada prestador (categoría, precio fijo o cotización). |
| `bookings` | Reservas (cliente, prestador, estado, precio, dirección, coordenadas del cliente, fotos, propina). |
| `chat_messages` | Mensajes por reserva (`type`: text/image/offer/counter_offer/location…). |
| `notifications` | Avisos in-app (tipos: bookingAccepted, requestExpired, etc.). |
| `verification_requests` | Solicitudes de verificación de identidad del prestador + resultado de Didit. |
| `push_subscriptions` | Suscripciones Web Push (VAPID) por navegador/dispositivo. |
| `app_settings` | Configuración editable (comisión, modo mantenimiento, contacto de soporte). |
| `app_secrets` | Secretos de servidor (claves VAPID, API key y webhook secret de Didit). RLS deny-all: solo el service role los lee. |

## Seguridad de datos (RLS)

Row Level Security activo en todas las tablas de usuario: cada quien lee/
escribe solo lo suyo. Patrón de rendimiento: `auth.uid()` se envuelve en
`(select auth.uid())` para que Postgres lo cachee una vez por consulta.

Las acciones de admin usan la función `SECURITY DEFINER` `public.is_admin()`
para evitar recursión de RLS sobre `profiles`.

Storage:
- `avatars`, `booking-photos`: buckets con RLS por carpeta (`<uid>/...`).
- `verification-docs`: bucket **privado**; el admin lee vía URLs firmadas
  (`createSignedUrl`), nunca públicas.

## Edge Functions

| Función | JWT | Propósito |
|---------|-----|-----------|
| `notify-new-request` | sí | Web Push bidireccional: avisa a prestadores de solicitudes nuevas de su nicho/provincia, y al cliente cuando aceptan su solicitud. |
| `didit-create-session` | sí | El prestador pide una sesión de verificación de identidad; devuelve la URL de Didit para abrir. |
| `didit-webhook` | no | Recibe el resultado de Didit; valida firma HMAC-SHA256 antes de aceptar. |
| `purge-verification-docs` | sí | Borra fotos de cédula/selfie 90 días después de revisadas (retención de datos). |

Las funciones sin `verify_jwt` (webhook de Didit) se protegen validando la
firma del emisor, no un JWT de Supabase.

## Trabajos programados (pg_cron)

| Job | Frecuencia | Acción |
|-----|-----------|--------|
| `expire-stale-open-requests` | cada hora (:15) | Cancela solicitudes `pending` sin prestador tras 24 h y avisa al cliente. |
| `purge-expired-verification-docs` | diario (03:30) | Invoca `purge-verification-docs`. |

## Triggers relevantes en `bookings`

- `bookings_notify_new_request` (INSERT): dispara push a prestadores del nicho.
- `bookings_notify_accepted` (UPDATE pending→accepted): dispara push al cliente.

Los triggers llaman a las Edge Functions vía `pg_net` (HTTP asíncrono) y nunca
bloquean la operación si el hook falla.

## Secretos

Nunca en el código (el repo es público). Viven en `app_secrets`:
`vapid_public_key`, `vapid_private_key`, `push_hook_secret`,
`didit_api_key`, `didit_workflow_id`, `didit_webhook_secret`.
La clave pública VAPID también está en `AppConstants` (no es secreta).
