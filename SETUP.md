# LimpiaYa — Guía de configuración

## 1. Instalar Flutter

1. Descarga Flutter SDK: https://docs.flutter.dev/get-started/install/windows
2. Extrae en `C:\src\flutter`
3. Agrega `C:\src\flutter\bin` al PATH
4. Ejecuta `flutter doctor` para verificar la instalación

## 2. Configurar Supabase

1. Crea una cuenta en https://supabase.com
2. Crea un nuevo proyecto
3. Ve a **SQL Editor** y pega el contenido de `supabase_schema.sql`, luego ejecútalo
4. Ve a **Settings > API** y copia:
   - **Project URL** → reemplaza `YOUR_SUPABASE_URL`
   - **anon public key** → reemplaza `YOUR_SUPABASE_ANON_KEY`
5. Ve a **Storage** y crea dos buckets públicos:
   - `avatars`
   - `provider-photos`

## 3. Configurar claves en la app

Edita `lib/core/constants/app_constants.dart`:

```dart
static const String supabaseUrl = 'https://xxxx.supabase.co';
static const String supabaseAnonKey = 'eyJhbGc...';
static const String googleMapsApiKey = 'AIzaSy...';
static const String stripePublishableKey = 'pk_test_...';
```

## 4. Configurar Google Maps

### Android
Edita `android/app/src/main/AndroidManifest.xml` y agrega antes de `</application>`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="TU_API_KEY_AQUI"/>
```

### iOS
Edita `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps
GMSServices.provideAPIKey("TU_API_KEY_AQUI")
```

## 5. Instalar dependencias y correr

```bash
flutter pub get
flutter run
```

Para web:
```bash
flutter run -d chrome
```

Para construir APK de Android:
```bash
flutter build apk --release
```

## 6. Configurar Stripe (Fase 2)

1. Crea cuenta en https://stripe.com
2. Obtén tu `Publishable Key` del dashboard
3. Para procesar pagos en el servidor, necesitarás una función de Supabase Edge Function

## Estructura del proyecto

```
lib/
├── main.dart                 # Punto de entrada
├── app.dart                  # App root con router
├── core/
│   ├── constants/            # Colores, constantes
│   ├── theme/                # Tema de la app
│   ├── router/               # Rutas (go_router)
│   └── services/             # Supabase service
└── features/
    ├── auth/                 # Login, registro, splash
    ├── home/                 # Pantalla principal
    ├── providers_list/       # Lista y perfil de prestadores
    ├── booking/              # Flujo de reserva
    ├── provider_dashboard/   # Panel del prestador
    └── profile/              # Perfil del usuario
```

## Flujo de usuarios

### Cliente
1. Splash → Onboarding → Registro/Login
2. Home → Selecciona categoría
3. Lista de prestadores → Perfil del prestador
4. Solicitar servicio → Confirmación
5. Ver mis servicios → Calificar

### Prestador
1. Registro como "prestador"
2. Panel principal con solicitudes
3. Aceptar/Rechazar solicitudes
4. Gestionar disponibilidad
5. Ver ingresos y estadísticas
