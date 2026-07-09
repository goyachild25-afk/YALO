# YALO — Estado del proyecto

> Documento vivo. Se actualiza cada vez que se despliega algo importante. Si estás leyendo esto en una sesión nueva de Claude Code: este archivo es la fuente de verdad del estado del proyecto — más confiable que memorias sueltas o docs antiguos (`ESTADO_PROYECTO_FLUTTER.md`, `CAMBIOS_REALIZADOS.md`, `TECH_AUDIT_20260624.md`, etc. quedaron obsoletos y no se actualizan más).

**Última actualización:** 2026-07-08
**Repo:** `goyachild25-afk/Serviciosya` (nombre del repo no cambió aunque la marca sí — ver "Branding" abajo)
**URL en producción:** https://goyachild25-afk.github.io/Serviciosya/
**Supabase project ref:** `ivexcnunszcqoqzzdlfz`

---

## Qué es YALO

Marketplace Flutter web para servicios del hogar en República Dominicana (limpieza, plomería, electricidad, jardinería, cuidado, mudanzas, etc.). Conecta clientes con prestadores. Modelo de ingreso: comisión del 10% por servicio (5% se le carga al cliente como "Garantía YALO", 5% se le descuenta al prestador como "Membresía de Visibilidad").

**Stack:** Flutter 3.32.0 · Supabase (Auth, Postgres+RLS, Realtime, Storage, Edge Functions, pg_cron, pg_net) · GitHub Pages · GitHub Actions CI/CD (verify → build → deploy, bloquea el deploy si fallan `flutter analyze` o `flutter test`).

**Modo demo:** la app tiene un modo demo completo (sin backend) accesible desde el login, útil para mostrar el producto sin cuenta real.

---

## Branding

Rebrandeada de **"ServiciosYa" a "YALO"** (julio 2026) porque ONAPI rechazó el registro original — el nombre ya estaba trademarked por otra marca. Slogan: *"¿Ya lo resolviste? Con YALO, sí."* Logo: casa + check, gradiente azul → coral/dorado.

- El repo de GitHub y la URL de deploy **deliberadamente no se renombraron** (evita romper las redirect URLs de Supabase Auth). Plan: migrar a dominio propio `yalo.do` cuando se compre.
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

### KYC de identidad (en integración — 2026-07-08)

Se decidió usar **Didit** (didit.me) para verificar cédula + selfie de los prestadores de forma automatizada (documento auténtico + comparación facial + detección de vida), como capa adicional a la revisión manual del admin (la IA nunca aprueba sola).

- Cuenta creada, organización "YALO"
- API key generada y guardada de forma segura en `app_secrets` (tabla protegida por RLS, nunca en el código — el repo es público)
- Flujo de verificación elegido: **"Free KYC"** (ID Verification + Liveness + Face Match), gratis hasta 500 verificaciones/mes — descartamos "Biometric Authentication" (no verifica documento) y "KYC + AML" (incluye screening de lavado de dinero, innecesario para este negocio y más caro)
- **Pendiente:** ID completo del flujo "Free KYC" (para terminar de armar la Edge Function que crea la sesión de verificación y recibe el resultado vía webhook), y conectar ese resultado al panel de verificaciones del admin como un score de apoyo (no como aprobación automática)
- El conector MCP que ofrece Didit para gestionar la cuenta desde Claude quedó descartado — no se conectó a esta sesión de Claude Code (parece ser para claude.ai, un producto distinto); se sigue el camino directo API key + Edge Function

---

## Pendiente

### 1. Pasarela de pago (bloqueado por formalización fiscal — ver arriba)
- Definir estructura fiscal con el contable
- RNC + cuenta comercial
- Afiliación AZUL/CardNET o Fygaro
- Conectar `payment_service.dart` al cobro real (hoy solo registra intención; el pago se acuerda en efectivo directo con el prestador, con aviso honesto de "fase piloto" en la pantalla de pago)

### 2. Sistema "YALO Puntos" (diseñado, no implementado)
Cashback 2-3% en puntos por pagar dentro de la app (canjeable como descuento, expira a los 90 días) — pensado para formar el hábito de pago in-app *antes* de que exista la pasarela real, ganándose por completar la reserva dentro de la app. Complementa:
- **Garantía YALO** con dientes reales (reembolso si el trabajo sale mal, solo si se pagó por la app)
- Niveles del prestador ya atados a trabajos completados — ampliar a "solo cuenta si se pagó in-app"
- Promo de lanzamiento: 0% membresía primeros 10 trabajos del prestador
- Constancia de ingresos descargable para prestadores (útil para préstamos/visados)

### 3. Panel Admin — mejoras identificadas, no implementadas
- Conectar de verdad el campo "Comisión (%)" de Configuración al cálculo real (hoy es decorativo; el cálculo vive hardcoded en `AppConstants.clientFee`/`providerFee`) — separar en dos campos (% cliente / % prestador)
- Exportar Finanzas a CSV
- Notificación al admin cuando llega verificación/disputa nueva
- Botón "Contactar" directo en Usuarios y Disputas
- Métrica "tiempo hasta primera aceptación" en Analytics
- Suspensión de usuario con motivo visible para el usuario

### 4. Panel Prestador — mejoras identificadas, no implementadas
- Desglose de ganancia neta por trabajo en la tarjeta ("Recibirás RD$950 tras membresía 5%")
- Historial de trabajos completados (hoy desaparecen de la lista, solo quedan en el contador)
- Filtro/orden por distancia además de provincia (Haversine ya existe en el código)
- Cancelación con motivo y estado propio (`cancelled_by_provider`), separado de "rechazada"

### 5. Deuda técnica
- ~231 usos de `AppColors.textPrimary` (color hardcoded) impiden reactivar modo oscuro — hoy forzado a claro para evitar texto invisible

### 6. Bloqueado por el usuario (no accionable por Claude sin su intervención)
- Revisión legal de Términos/Privacidad por abogado dominicano
- Compra de dominio `yalo.do` y migración de GitHub Pages
- Activación de Sentry DSN real

---

## Notas para quien retome este proyecto

- CI requiere Flutter 3.32.0 exacto (instalado en `C:\Users\JJLA-\flutter_3320\`) — usar ese binario para `analyze`/`build`, no el Flutter principal del sistema, o el build puede diverger de lo que corre en GitHub Actions. `flutter test` sí puede correr con el Flutter del sistema.
- Antes de tocar `pubspec.yaml` o dependencias, recordar: `pubspec.lock` diverge entre los dos installs de Flutter — hacer `git checkout -- pubspec.lock` antes de compilar con el de CI.
- Antes de trabajar en pagos/comisiones: preguntar si ya hay respuesta del contable — cambia la implementación.
