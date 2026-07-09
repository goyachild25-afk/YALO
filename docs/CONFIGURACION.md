# Configuración y despliegue

## Requisitos

- **Flutter 3.32.0 exacto** para builds que deben coincidir con el CI.
  El proyecto usa una instalación dedicada en `C:\Users\JJLA-\flutter_3320\`.
  Usar ese binario para `analyze` y `build`; el Flutter del sistema puede
  divergir de lo que corre en GitHub Actions.
- `flutter test` sí puede correr con el Flutter del sistema.

> Antes de tocar `pubspec.yaml` o dependencias: `pubspec.lock` diverge entre
> las dos instalaciones de Flutter. Ejecutar `git checkout -- pubspec.lock`
> antes de compilar con el de CI.

## Desarrollo local

```bash
flutter pub get
flutter run -d chrome
```

## Variables / claves

Las claves de cliente (Supabase URL + anon key, Google Maps, VAPID pública)
viven en `lib/core/constants/app_constants.dart`. La anon key y la clave VAPID
pública **no son secretas** (están diseñadas para el cliente). Los secretos de
servidor viven en la tabla `app_secrets` de Supabase, nunca en el repo
(ver [BACKEND.md](BACKEND.md)).

## Build de producción

```bash
flutter build web --release --no-tree-shake-icons --base-href /Serviciosya/
```

El `base-href /Serviciosya/` es obligatorio: GitHub Pages sirve la app bajo
ese subpath.

## CI/CD (GitHub Actions)

Pipeline de 3 etapas en `.github/workflows/deploy.yml`; cada una bloquea la
siguiente si falla:

1. **verify** — `flutter analyze --no-fatal-infos --no-fatal-warnings` +
   `flutter test`.
2. **build** — `flutter build web --release` con el base-href.
3. **deploy** — publica a GitHub Pages.

Un push a `main` dispara el pipeline. Si `analyze` o `test` fallan, no se
despliega.

## Nota sobre migraciones de base de datos

Las migraciones de Supabase se aplican directo contra el proyecto (no pasan
por el CI de GitHub Actions). Un cambio de esquema o una función SQL corregida
está en vivo apenas se aplica, sin desplegar la app.

## Despliegue y URL

- Repo: `goyachild25-afk/Serviciosya`
- URL: https://goyachild25-afk.github.io/Serviciosya/

El nombre del repo y la URL conservan "Serviciosya" a propósito (renombrarlos
rompería las URLs de redirección de Supabase Auth). Migración a `yalo.do`
planificada — ver [ESTADO.md](ESTADO.md).
