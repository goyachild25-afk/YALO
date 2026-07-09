# YALO

**¿Ya lo resolviste? Con YALO, sí.**

Marketplace de servicios del hogar para República Dominicana. Conecta clientes
con prestadores verificados (limpieza, plomería, electricidad, jardinería,
cuidado, mudanzas, etc.) con reserva inmediata, chat, ubicación en vivo y
verificación de identidad.

- **App en producción:** https://goyachild25-afk.github.io/Serviciosya/
- **Stack:** Flutter Web · Supabase · GitHub Pages · CI/CD con GitHub Actions

> Nota de marca: el repositorio y la URL conservan el nombre técnico
> `Serviciosya` por razones de infraestructura (renombrarlos rompería las
> URLs de redirección de autenticación). La app está 100 % rebrandeada a
> **YALO**. La migración al dominio `yalo.do` está planificada. Ver
> [docs/ESTADO.md](docs/ESTADO.md).

---

## Documentación

Toda la documentación vive en [`docs/`](docs/), un tema por archivo:

| Documento | Contenido |
|-----------|-----------|
| [docs/ESTADO.md](docs/ESTADO.md) | **Fuente de verdad** del estado del proyecto: qué funciona, qué falta, incidentes. Se actualiza tras cada despliegue importante. |
| [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) | Estructura del código, features por rol, navegación, gestión de estado. |
| [docs/BACKEND.md](docs/BACKEND.md) | Supabase: tablas, RLS, Edge Functions, trabajos programados, secretos. |
| [docs/CONFIGURACION.md](docs/CONFIGURACION.md) | Entorno de desarrollo, versión de Flutter, build, despliegue y CI. |
| [docs/SEGURIDAD_Y_PRIVACIDAD.md](docs/SEGURIDAD_Y_PRIVACIDAD.md) | Verificación de identidad (KYC), retención de datos, Ley 172-13. |

---

## Arranque rápido

```bash
flutter pub get
flutter run -d chrome        # desarrollo local
```

Para el detalle de la versión exacta de Flutter, variables de entorno, build
de producción y despliegue, ver [docs/CONFIGURACION.md](docs/CONFIGURACION.md).

---

## Roles

- **Cliente (solicitante):** busca y reserva servicios, chatea, comparte
  ubicación, paga, califica.
- **Prestador:** configura servicios y precios, se verifica, recibe y acepta
  solicitudes, navega hasta el cliente.
- **Admin:** verifica identidades, resuelve disputas, gestiona usuarios y
  reservas, ve finanzas y analytics.
