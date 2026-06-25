# ServiciosYa - Local Development Setup Guide

**Last Updated:** June 24, 2026  
**Language:** Spanish (Español)

---

## 📋 Requisitos Previos

- **Flutter** 3.32.0+ ([Download](https://flutter.dev))
- **Dart** 3.6.0+ (incluido con Flutter)
- **Android Studio** o **VS Code** con Flutter extension
- **Git**
- **Supabase CLI** (opcional, para migraciones)
- **iOS xcode** (si desarrollas para iOS)

### Verificar Instalación

```bash
flutter --version
dart --version
```

---

## 🔧 Instalación Local

### 1. Clonar el Repositorio

```bash
cd ~/Projects  # o tu carpeta de proyectos
git clone https://github.com/goyachild25/serviciosya.git
cd serviciosya
```

### 2. Instalar Dependencias

```bash
flutter pub get
```

### 3. Configurar Supabase

La app usa Supabase para backend. Tienes dos opciones:

#### Opción A: Usar Supabase Production (Recomendado)
Las credenciales ya están en `lib/core/constants/app_constants.dart`:
```dart
const String supabaseUrl = 'https://[url-aqui].supabase.co';
const String supabaseAnonKey = '[key-aqui]';
```

#### Opción B: Setup Local de Supabase (Avanzado)
```bash
# Instalar Supabase CLI
npm install -g supabase

# Iniciar servidor local
supabase start

# Migrations se aplicarán automáticamente
```

### 4. Generar Código (Riverpod + Build Runner)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## ▶️ Ejecutar la App

### Mobile (Android)

```bash
# Debug
flutter run -d android

# Profile (optimizado pero debuggable)
flutter run -d android --profile

# Release
flutter run -d android --release
```

### iOS (macOS/Xcode requerido)

```bash
flutter run -d ios
```

### Web

```bash
# Debug (abre Chrome automáticamente)
flutter run -d chrome

# Release
flutter build web --release
# Archivos en: build/web/
```

### Emulador Android Específico

```bash
# Listar emuladores disponibles
emulator -list-avds

# Ejecutar emulador específico
emulator -avd Pixel_5_API_33

# Luego correr la app
flutter run
```

---

## 📱 Testing en Dispositivo Real

### Android
1. Conecta el dispositivo via USB
2. Habilita "USB Debugging" en Configuración → Opciones de Desarrollador
3. Aprueba el acceso en el diálogo del dispositivo
4. Corre: `flutter devices` para verificar
5. Corre: `flutter run`

### iOS
1. Conecta el dispositivo via USB
2. Abre Xcode: `open ios/Runner.xcworkspace`
3. Selecciona el dispositivo en el selector
4. Corre el build (⌘R)

---

## 🧪 Ejecutar Tests

```bash
# Tests unitarios
flutter test

# Tests específicos
flutter test test/features/auth/

# Coverage
flutter test --coverage
# Reporte: coverage/lcov.info

# Con observador de cambios (re-corre tests al guardar)
flutter test --watch
```

---

## 🔍 Debugging

### Debug Mode
```bash
flutter run -v  # Verbose logging
```

### DevTools (Inspector, Debugger, Performance)
```bash
dart devtools

# O automáticamente con:
flutter run
# Luego presiona 'd' en la terminal
```

### Breakpoints en VS Code
1. Abre el archivo Dart
2. Click al lado del número de línea (punto rojo)
3. Ejecuta: `flutter run`
4. Cuando se alcance el breakpoint, aparecerá el debugger

### Logs
```bash
flutter run 2>&1 | grep "⚠️|❌|✓"
```

### Device Logs (Android)
```bash
adb logcat
```

---

## 🔐 Variables de Entorno

Crea un archivo `.env` en la raíz (NO commitar):

```env
SUPABASE_URL=https://[project].supabase.co
SUPABASE_ANON_KEY=eyJhbG...
GOOGLE_MAPS_API_KEY=AIzaSyA...
```

Para usarlas, instala: `flutter_dotenv`

---

## 🗂️ Estructura del Proyecto

```
lib/
  ├── main.dart                 # Entry point
  ├── app.dart                  # App shell con Material + Router
  ├── core/
  │   ├── constants/           # app_colors.dart, app_constants.dart
  │   ├── router/              # app_router.dart (go_router)
  │   ├── services/            # supabase_service.dart, notification_service.dart
  │   └── theme/               # app_theme.dart
  ├── features/
  │   ├── auth/                # Login, Signup, Splash, Onboarding
  │   ├── home/                # Home screen (Client)
  │   ├── provider_dashboard/  # Dashboard (Provider)
  │   ├── booking/             # Booking flow
  │   ├── chat/                # Real-time chat
  │   ├── profile/             # User profiles
  │   ├── notifications/       # Notifications
  │   └── ...
  └── models/                  # Shared data models

test/
  ├── features/
  │   ├── auth/
  │   ├── booking/
  │   └── ...
  └── core/

supabase/
  ├── migrations/              # SQL migrations (.sql)
  └── seed.sql                 # Demo data
```

---

## 🚀 Build & Deployment

### Web (GitHub Pages)

```bash
# Build release
flutter build web --release

# Archivos en: build/web/

# Subir a GitHub Pages
git add build/web/
git commit -m "Deploy: web build"
git push origin main

# GitHub Actions despliega automáticamente
# Ver: .github/workflows/deploy.yml
```

### APK (Android)

```bash
flutter build apk --release
# Archivo: build/app/outputs/apk/release/app-release.apk
```

### AAB (Google Play)

```bash
flutter build appbundle --release
# Archivo: build/app/outputs/bundle/release/app-release.aab
```

---

## 🐛 Troubleshooting

### "Flutter not found"
```bash
# Añade Flutter al PATH
export PATH="$PATH:[ruta-flutter]/bin"
```

### "Waiting for connection from debug service"
```bash
# Limpia cache
flutter clean
flutter pub get

# Re-inicia
flutter run
```

### "Google Maps: ERROR - Este sitio no puede acceder"
```
# El API key está restringido a dominio específico
# Solución: Genera una nueva key sin restricciones en Google Cloud Console
```

### Errores de Dependencias
```bash
# Resuelve conflictos
flutter pub upgrade --major-versions

# O revierte a versión conocida
flutter pub get
```

### "Build failed - No matching root package"
```bash
cd ~/mi_app/Serviciosya  # Asegúrate de estar en la carpeta correcta
flutter clean
flutter pub get
flutter run
```

---

## 📚 Recursos Útiles

- **Flutter Docs:** https://docs.flutter.dev
- **Riverpod Docs:** https://riverpod.dev
- **Supabase Docs:** https://supabase.com/docs
- **go_router Docs:** https://pub.dev/packages/go_router
- **Dart Linter:** https://dart.dev/guides/language/analysis-options

---

## ✅ Checklist Pre-Commit

Antes de hacer `git commit`:

```bash
# 1. Format code
flutter format lib/

# 2. Analyze
flutter analyze

# 3. Run tests
flutter test

# 4. Build web
flutter build web --release

# 5. Commit
git add -A
git commit -m "feat: descripción clara"
```

---

**¿Preguntas?** Revisa ARCHITECTURE.md o contacta al equipo de desarrollo.
