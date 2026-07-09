# Seguridad y privacidad

## Verificación de identidad de prestadores (KYC)

La seguridad del hogar del cliente es el eje del negocio: nadie llega a la
puerta de un cliente sin haber pasado por verificación de identidad **y** la
aprobación manual del admin.

### Proveedor: Didit

Se usa [Didit](https://didit.me) para verificar cédula + selfie de forma
automatizada (documento auténtico + comparación facial + detección de vida en
tiempo real). Flujo "Free KYC" (gratis hasta 500 verificaciones/mes).

### Flujo obligatorio

1. Registro → código al correo → configuración de servicios y precios.
2. **Verificación de identidad obligatoria** (`/verify-identity`): sin salida
   cuando se llega desde el onboarding. El dashboard rebota a esta pantalla a
   cualquier prestador que no la haya completado.
3. El prestador acepta el consentimiento explícito y captura cédula + selfie
   en la sesión hospedada de Didit (cámara en vivo — la detección de vida no
   funciona sobre una foto ya tomada).
4. Didit reporta el resultado por webhook (`didit-webhook`), que valida la
   firma HMAC-SHA256 antes de guardar `didit_status`.
5. Mientras el admin no aprueba: el prestador puede configurar su perfil pero
   **no aceptar solicitudes** (banner "en revisión" + bloqueo en el código).
6. El admin ve el resultado de Didit como apoyo y da la **aprobación final**
   manual → se enciende `is_verified` y se desbloquea aceptar trabajos.

**La IA nunca aprueba sola.** Doble candado: Didit filtra automático, el admin
confirma.

## Retención de datos biométricos

- Consentimiento explícito registrado con fecha (`consent_given_at`) antes de
  procesar cédula/selfie.
- Las imágenes de verificación se eliminan automáticamente **90 días** después
  de revisadas (job `purge-expired-verification-docs`). El resultado de la
  verificación se conserva para auditoría; las imágenes no.
- En el flujo nuevo con Didit, las imágenes las custodia Didit, no YALO.

## Cumplimiento (Ley 172-13, RD)

- Derechos ARCO + portabilidad: botones "Descargar mis datos" y "Eliminar mi
  cuenta" en el perfil (Edge Functions con service role).
- Términos y Política de Privacidad en la app (`safety/screens/terms_screen`),
  con política de retención y mención del proveedor externo de KYC.
- Cifrado en tránsito (HTTPS/TLS). Secretos fuera del repo.
- Anti-spam en el chat: bloquea intercambio de teléfonos/emails para evitar
  disintermediación y proteger a ambas partes.

> Pendiente: revisión legal de Términos/Privacidad por un abogado dominicano
> antes del lanzamiento público a gran escala.

## Otras medidas

- RLS en toda la base de datos (ver [BACKEND.md](BACKEND.md)).
- Bucket de documentos de verificación privado, con URLs firmadas de acceso
  temporal solo para el admin.
- Modo mantenimiento operable desde el panel admin para bloquear la app en
  caso de incidente.
