# YALO — Estado del proyecto

> Documento vivo. Se actualiza cada vez que se despliega algo importante. Si estás leyendo esto en una sesión nueva de Claude Code: este archivo es la fuente de verdad del **estado** del proyecto (qué funciona, qué falta, incidentes). Para arquitectura, backend, configuración y seguridad ver los demás archivos en [`docs/`](.).

**Última actualización:** 2026-07-16
**Repo:** `goyachild25-afk/YALO`
**URL en producción:** https://goyachild25-afk.github.io/YALO/
**Supabase project ref:** `ivexcnunszcqoqzzdlfz`

---

## ⚠️ Incidente resuelto (2026-07-16): la suspensión de usuarios no bloqueaba el acceso

Al conectar el motivo de suspensión al panel Admin se encontró que suspender
a un usuario no le impedía seguir usando la app con normalidad. Corregido en
varias capas — login, navegación, y a nivel del servidor de autenticación
(nueva Edge Function `suspend-user`; motivo visible al usuario en
`profiles.suspension_reason`). Detalles técnicos específicos no se documentan
aquí por ser un repositorio público. Queda pendiente como mejora de defensa
en profundidad (no bloqueante) reforzar las políticas RLS existentes en las
tablas de negocio — ver Pendiente → Deuda técnica.

## ⚠️ Incidente resuelto (2026-07-09): registro de usuarios caído

El registro de cuentas nuevas (`/auth/v1/signup`) devolvía error 500 para el 100% de los intentos — "Database error saving new user". Causa: `public.gen_referral_code(uuid)` llamaba a `digest()` (de la extensión `pgcrypto`) sin calificar el esquema; funcionaba en el editor SQL de Supabase (cuyo `search_path` incluye `extensions`) pero fallaba en el contexto real del signup, que no lo incluye. Arreglado calificando la llamada como `extensions.digest(...)` (migración `fix_gen_referral_code_schema_qualify_digest`). Verificado con un registro real de prueba — funciona, cuenta de prueba eliminada después. Sin cambios de código Flutter, ya está en vivo (las migraciones de Supabase aplican directo, no pasan por el CI de GitHub Actions).

---

## Qué es YALO

Marketplace Flutter web para servicios del hogar en República Dominicana (limpieza, plomería, electricidad, jardinería, cuidado, mudanzas, etc.). Conecta clientes con prestadores. Modelo de ingreso: comisión del 10% por servicio (5% se le carga al cliente como "Garantía YALO", 5% se le descuenta al prestador como "Membresía de Visibilidad").

**Stack:** Flutter 3.32.0 · Supabase (Auth, Postgres+RLS, Realtime, Storage, Edge Functions, pg_cron, pg_net) · GitHub Pages · GitHub Actions CI/CD (verify → build → deploy, bloquea el deploy si fallan `flutter analyze` o `flutter test`).

**Modo demo:** la app tiene un modo demo completo (sin backend) accesible desde el login, útil para mostrar el producto sin cuenta real.

---

## Branding

La marca es **YALO** (adoptada en julio 2026, tras que ONAPI rechazara el nombre anterior por estar ya registrado por otra marca). Slogan: *"¿Ya lo resolviste? Con YALO, sí."* Logo: casa + check, gradiente azul → coral/dorado.

- El repo de GitHub se renombró a **YALO** (2026-07-09). El nombre de usuario de GitHub (`goyachild25-afk`) y el nombre del proyecto Supabase se dejan como están a propósito: solo son visibles en la URL de `github.io` / el dashboard, y se vuelven irrelevantes al migrar al dominio propio `yalo.do` (planificado cuando se compre).
- **Registro de marca YALO en ONAPI:** en trámite, categoría #35. En espera de respuesta.

---

## Formalización fiscal (bloquea la pasarela de pago)

En curso con contable externo. Se le envió un resumen del modelo de negocio (comisión de intermediación, prestadores como contratistas independientes, fondos de terceros en custodia) para que determine:

1. Persona física con negocio vs. SRL
2. RNC en DGII + régimen (RST vs. ordinario)
3. Registro Mercantil (si aplica)
4. Comprobantes fiscales (NCF) / facturación electrónica (e-CF, Ley 32-23)
5. Tratamiento de ITBIS sobre la comisión (no sobre el valor total del servicio)
6. ISR y retenciones
7. Cuenta bancaria comercial (requisito de AZUL/CardNET — normalmente no aceptan cuenta de ahorros personal)
8. Iguala mensual de declaraciones

**Estado:** esperando respuesta del contable. La estructura que elijan determina cómo se implementa la facturación dentro de la app (NCF por transacción, desglose de ITBIS en el recibo, reporte mensual de comisiones).

**Ruta hacia la pasarela una vez formalizado:**
- Afiliación comercial a AZUL o CardNET (e-commerce), o alternativa más ágil: agregador tipo **Fygaro** montado sobre AZUL/CardNET con papeleo más ligero.
- PayPal descartado como vía principal (retiro a banco dominicano no soportado directamente).
- Asesoría gratuita disponible: Centros MIPYMES (MICM, en universidades), portal `formalizate.gob.do`, unidades de orientación DGII.

---

## Qué está funcionando en producción

### Los tres paneles (roles: cliente, prestador, admin)

**Cliente:** Home con categorías y buscador (con búsqueda por voz donde el navegador lo soporta), solicitud inmediata ("Ya") con radar en tiempo real, reserva directa con prestador elegido, Mis servicios con historial y acciones por estado, chat con negociación de precio, perfil con referidos/favoritos/accesibilidad, cumplimiento Ley 172-13 (descarga/borrado de datos).

**Prestador:** Dashboard con estadísticas propias, niveles (New/Destacado/Experto/Élite) con barra de progreso, mapa de actividad en tiempo real, gestión de servicios (CRUD, precio fijo o por cotización), toggle de disponibilidad (bug corregido: ahora sí lee el estado real de la BD al abrir).

**Admin:** control total — verificaciones de identidad, disputas, usuarios (editar/suspender/dar rol admin), reservas (forzar estado/reasignar/reembolsar/cancelar), finanzas (ingresos, categorías), configuración (modo mantenimiento — funcional), analytics (embudo de conversión), auditoría de acciones.

### Infraestructura que conecta ambos lados (construida en las últimas sesiones)

- **Web Push nativo (VAPID, sin Firebase)** — bidireccional: el prestador recibe push de solicitudes nuevas de su nicho/provincia con la app cerrada; el cliente recibe push cuando aceptan su solicitud. Motor: Edge Function `notify-new-request` + triggers `pg_net` en `bookings`.
- **Ubicación GPS real** — capturada en toda solicitud (inmediata y directa), compartible manualmente por chat (tarjeta tocable), botón "Cómo llegar" en reservas aceptadas del prestador que abre Google Maps/Waze/copiar coordenadas.
- **Fotos de perfil visibles en el chat** (ambos lados, antes no se veían) con visor a pantalla completa estilo Instagram (zoom, toque para abrir/cerrar) — también en el perfil del prestador.
- **Auto-expiración de solicitudes** sin prestador tras 24h (`pg_cron`), con aviso al cliente y botón "Pedir de nuevo" en reservas completadas (recompra en un toque).
- **Anti-spam en el chat** — bloquea intercambio de teléfonos/emails para evitar que se salten la plataforma.
- **Visor de foto de perfil estilo Instagram** — un toque en cualquier avatar (chat, perfil de prestador) lo abre en grande con zoom.
- **Consentimiento explícito + retención de documentos de verificación** — el prestador debe aceptar una casilla clara antes de enviar cédula/selfie (queda con fecha de aceptación en `verification_requests.consent_given_at`). Las imágenes se borran automáticamente 90 días después de revisadas (`purge-verification-docs`, Edge Function + `pg_cron` diario a las 3:30am); el resultado de la verificación se conserva para auditoría. Términos/Privacidad actualizados con la política de retención y la mención del proveedor externo de KYC.

### KYC de identidad con Didit — integrado (2026-07-08)

Se usa **Didit** (didit.me) para verificar cédula + selfie de los prestadores de forma automatizada (documento auténtico + comparación facial + detección de vida en tiempo real). Reemplaza por completo el upload manual de 3 fotos — Didit necesita captura en vivo con su propia cámara, no se puede aplicar sobre una foto ya tomada.

- App "My Application" en la organización "YALO" (no confundir con "YALO (Sandbox)", que se creó aparte); flujo usado: **"Free KYC"** (`90e027f5-3f62-493d-844e-69275e360f7d`) — ID Verification + Liveness + Face Match, gratis hasta 500 verificaciones/mes. Publicada (salió de `draft`).
- Secretos guardados en `app_secrets` (nunca en el código): `didit_api_key`, `didit_workflow_id`, `didit_webhook_secret`.
- **Backend:** `didit-create-session` (el prestador pide una sesión, autenticado) → `didit-webhook` (recibe el resultado, valida firma HMAC-SHA256, guarda en `verification_requests.didit_status` sin tocar la columna `status` que controla el admin).
- **Frontend:** pantalla de verificación del prestador con un botón que abre la sesión de Didit en pestaña nueva; panel admin muestra el resultado (`_DiditResultBadge`) junto a la revisión manual — la decisión final sigue siendo 100% humana.
- Verificado server-side (auth rechazada sin JWT, webhook rechaza sin firma válida). **Pendiente de prueba real por el usuario:** completar una captura en vivo de principio a fin (requiere cámara y persona real, no se puede automatizar) para confirmar que el webhook llega y el admin ve el resultado.
- **La verificación es OBLIGATORIA para operar (2026-07-09):** al terminar el onboarding, el prestador va directo a /verify-identity sin escape; el dashboard rebota a la verificación a quien no la haya completado; y hasta que el admin apruebe (`is_verified`), puede explorar su panel pero NO aceptar solicitudes (banner "identidad en revisión" + bloqueo en `_acceptRequest`). Razón de negocio: los prestadores entran a hogares — la seguridad del cliente no es negociable.
- **Fix estructural del mismo día:** el `routerProvider` se reconstruía con cada cambio de sesión/rol (reset a splash, saltándose verify-email y onboarding) — ahora se construye una sola vez con `refreshListenable`. Y `isOnboardingComplete` daba siempre true (comprobaba la fila de `profiles`, que un trigger crea sola al registrarse) — ahora exige la fila de `provider_profiles` para prestadores.
- **Bug encontrado por prueba end-to-end del webhook (2026-07-09):** `verification_requests` tenía `full_name`, `id_front_url` y `selfie_url` como NOT NULL (herencia del viejo flujo manual con subida de fotos). El flujo nuevo de Didit no llena ninguno (Didit conserva las imágenes) → TODA verificación de prestador habría reventado en producción. Corregido relajando esos NOT NULL (migración `verification_requests_relax_legacy_notnull_for_didit`). **Verificado end-to-end:** webhook con firma HMAC falsa → 401, con firma válida → 200 y `didit_status` se actualizó a "Approved" en la BD. Falta solo la captura con cámara real (prueba humana).
- El conector MCP que ofrece Didit para gestionar la cuenta desde Claude (visto en claude.ai, no en esta sesión de Claude Code) no se usó — se integró todo por API key + Edge Functions directamente.

---

## Pendiente

### 1. Pasarela de pago (bloqueado por formalización fiscal — ver arriba)
- Definir estructura fiscal con el contable
- RNC + cuenta comercial
- Afiliación AZUL/CardNET o Fygaro
- Conectar `payment_service.dart` al cobro real (hoy solo registra intención; el pago se acuerda en efectivo directo con el prestador). La pantalla de pago mostraba un flujo de "garantía" con tarjeta/reserva/cobro automático que nunca existió — corregido 2026-07-16 para reflejar el flujo real (confirmar reserva, pagar directo al prestador)

### 2. Sistema "YALO Puntos" (diseñado, no implementado)
Cashback 2-3% en puntos por pagar dentro de la app (canjeable como descuento, expira a los 90 días) — pensado para formar el hábito de pago in-app *antes* de que exista la pasarela real, ganándose por completar la reserva dentro de la app. Complementa:
- **Garantía YALO** con dientes reales (reembolso si el trabajo sale mal, solo si se pagó por la app)
- Niveles del prestador ya atados a trabajos completados — ampliar a "solo cuenta si se pagó in-app"
- Promo de lanzamiento: 0% membresía primeros 10 trabajos del prestador
- Constancia de ingresos descargable para prestadores (útil para préstamos/visados)

### 3. Panel Admin — mejoras identificadas, no implementadas
- ~~Conectar "Comisión (%)" al cálculo real~~ — hecho 2026-07-16: dos campos (% cliente / % prestador) en `app_settings`, `PaymentService` los carga en vivo
- ~~Exportar Finanzas a CSV~~ — hecho 2026-07-16
- ~~Suspensión de usuario con motivo visible~~ — hecho 2026-07-16 (ver hallazgo arriba)
- Notificación al admin cuando llega verificación/disputa nueva
- ~~Botón "Contactar" directo en Usuarios y Disputas~~ — hecho 2026-07-16: WhatsApp con el teléfono, o `mailto:` si no hay teléfono
- Métrica "tiempo hasta primera aceptación" en Analytics

### 4. Panel Prestador — mejoras identificadas, no implementadas
- ~~Desglose de ganancia neta por trabajo en la tarjeta~~ — hecho 2026-07-16
- ~~Historial de trabajos completados~~ — hecho 2026-07-16 (`/provider-history`)
- ~~Cancelación con motivo y estado propio~~ — hecho 2026-07-16: usa el status `cancelled` que ya existía (el cliente ya lo usaba), motivo anexado a `notes`, sin migración
- ~~Filtro/orden por distancia además de provincia~~ — hecho 2026-07-16: "Solicitudes para ti" ahora se ordena por cercanía real (Haversine) usando la ubicación del prestador, con la distancia visible en cada tarjeta; la provincia sigue siendo el filtro de la consulta, la distancia es el orden dentro de ella

### 5. Deuda técnica
- ~231 usos de `AppColors.textPrimary` (color hardcoded) impiden reactivar modo oscuro — hoy forzado a claro para evitar texto invisible
- Reforzar RLS con verificación de `is_active` en las tablas de negocio (defensa en profundidad — el bloqueo principal de la suspensión ya funciona, ver incidente resuelto arriba). Requiere revisar primero las políticas existentes de `bookings` y afines, que tienen bastante acumulación histórica (varias políticas superpuestas por tabla) — mejor hacerlo con un branch de Supabase para probar sin tocar producción directo.

### 6. Bloqueado por el usuario (no accionable por Claude sin su intervención)
- Revisión legal de Términos/Privacidad por abogado dominicano — v4 ya incorpora una ronda de revisión preliminar (fuerza mayor, propiedad intelectual, renuncia de garantías, reparación en especie sin efectivo, marca, impuestos del prestador — ver `lib/features/safety/screens/terms_screen.dart`), pero sigue pendiente la firma de un abogado licenciado
- Compra de dominio `yalo.do` y migración de GitHub Pages
- Activación de Sentry DSN real

---

## Notas para quien retome este proyecto

- CI requiere Flutter 3.32.0 exacto (instalado en `C:\Users\JJLA-\flutter_3320\`) — usar ese binario para `analyze`/`build`, no el Flutter principal del sistema, o el build puede diverger de lo que corre en GitHub Actions. `flutter test` sí puede correr con el Flutter del sistema.
- Antes de tocar `pubspec.yaml` o dependencias, recordar: `pubspec.lock` diverge entre los dos installs de Flutter — hacer `git checkout -- pubspec.lock` antes de compilar con el de CI.
- Antes de trabajar en pagos/comisiones: preguntar si ya hay respuesta del contable — cambia la implementación.
