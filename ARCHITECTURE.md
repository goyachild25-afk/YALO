# ServiciosYa - Architecture & Design Document

**Last Updated:** June 24, 2026  
**Author:** Senior Full-Stack Engineer

---

## 🏗️ System Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    SERVICIOSYA APP                           │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────┐ │
│  │   Flutter Web    │  │   Flutter Mobile │  │   Admin    │ │
│  │   (Browser)      │  │   (Android/iOS)  │  │   Panel    │ │
│  └────────┬─────────┘  └────────┬─────────┘  └────────┬───┘ │
│           │                      │                      │     │
│           └──────────────────────┼──────────────────────┘     │
│                                  │                             │
│                          ┌────────▼────────┐                  │
│                          │  go_router v14  │ (Navigation)     │
│                          └────────┬────────┘                  │
│                                  │                             │
│                          ┌────────▼────────┐                  │
│                          │  Riverpod v2.6  │ (State)         │
│                          └────────┬────────┘                  │
│                                  │                             │
└──────────────────────────────────┼──────────────────────────┘
                                   │
                      ┌────────────┴─────────────┐
                      │                          │
          ┌───────────▼────────────┐   ┌────────▼───────────┐
          │   Supabase (Backend)   │   │   Google Maps API  │
          │   - PostgreSQL         │   │   - Geolocator     │
          │   - Real-time (PG)     │   │   - Location Sync  │
          │   - Auth (GoTrue)      │   │                    │
          │   - Storage (S3)       │   └────────────────────┘
          └───────────┬────────────┘
                      │
          ┌───────────▼────────────┐
          │     DATABASE SCHEMA    │
          │                        │
          │  - users (auth)        │
          │  - profiles            │
          │  - provider_profiles   │
          │  - provider_services   │
          │  - bookings            │
          │  - chat_messages       │
          │  - notifications       │
          │  - reviews             │
          └────────────────────────┘
```

---

## 📦 Dependency Layers

### Layer 1: Core (No dependencies on features)
- `app_colors.dart` - Design system colors
- `app_constants.dart` - API keys, URLs
- `supabase_service.dart` - Database client
- `notification_service.dart` - Push notifications
- `payment_service.dart` - Payment processing
- `demo_provider.dart` - Demo mode (for testing)

### Layer 2: Features (Domain logic)
Each feature is self-contained:
- `auth/` - Authentication & authorization
- `home/` - Client home screen
- `provider_dashboard/` - Provider dashboard
- `booking/` - Booking workflow
- `chat/` - Real-time messaging
- `profile/` - User profiles
- `notifications/` - Notification center

### Layer 3: Widgets (Presentational)
- `screens/` - Full screens
- `widgets/` - Reusable components
- `models/` - Data models

---

## 🔄 State Management Pattern (Riverpod)

### Providers Used:

```dart
// Simple state
final counterProvider = StateProvider((ref) => 0);

// Computed state (derived)
final doubleCountProvider = Provider((ref) {
  return ref.watch(counterProvider) * 2;
});

// Async data (from API)
final bookingsProvider = FutureProvider((ref) async {
  return await fetchBookings();
});

// Real-time streams (Supabase)
final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, bookingId) {
  return SupabaseService.client
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .eq('booking_id', bookingId);
});

// State notifier (complex state mutations)
final authStateProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier(ref);
});
```

### Data Flow:

```
┌─────────────────────────────────────────────────────────┐
│                   USER INTERACTION                      │
│               (button tap, form submit)                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────────┐
         │  Riverpod Provider        │  (Listens to ref.watch)
         │  (StateNotifier)          │
         └────────┬──────────────────┘
                  │
                  ▼
      ┌────────────────────────┐
      │  Service Layer         │  (Business logic)
      │  - SupabaseService     │
      │  - PaymentService      │
      │  - NotificationService │
      └────────┬───────────────┘
               │
               ▼
      ┌────────────────────────┐
      │  Database / API        │  (Supabase)
      │  - PostgreSQL          │
      │  - Real-time subscriptions
      └────────────────────────┘

DATA RETURNS:
  Database → Service → Provider → UI (rebuild)
```

---

## 🔐 Authentication & Authorization

### Flow:

1. **Anonymous** → Pre-login screens (login, register, forgot password)
2. **Login** → Email/Password auth via Supabase GoTrue
3. **Redirect** → Role-based (client vs provider)
4. **Authenticated** → Full app access

### Role-Based Access Control (RBAC):

```dart
enum UserRole { client, provider, admin }

// In router:
if (userRole == UserRole.provider) {
  return '/dashboard';  // Provider dashboard
} else {
  return '/home';       // Client home
}

// In widgets:
if (isProvider) {
  // Show provider-specific UI
}
```

### Row-Level Security (RLS) in Supabase:

```sql
-- Only users can see their own profile
CREATE POLICY "read_own_profile" ON profiles
  FOR SELECT TO authenticated
  USING (auth.uid() = id);

-- Providers can only update their own profile
CREATE POLICY "update_own_profile" ON profiles
  FOR UPDATE TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
```

**CRITICAL:** See `20260624_fix_rls_security.sql` for complete RLS setup.

---

## 💬 Real-Time Chat System

### Architecture:

```
Client A (Browser)
    │
    └─► Supabase Realtime
         │
         ├─► PostgreSQL LISTEN/NOTIFY
         │
         └─► Supabase replication
             │
             └─► Client B (Mobile)
```

### Implementation:

```dart
final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, bookingId) {
    return SupabaseService.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId)
        .order('created_at');
  }
);

// In UI:
final messages = ref.watch(chatMessagesProvider(bookingId));
messages.whenData((list) {
  // Automatically re-builds when new messages arrive
});
```

### Key Tables:

- `chat_messages` - Text, offer, counter-offer messages
- `bookings` - Contains `negotiation_status` and `agreed_price`

---

## 💳 Booking & Payment Flow

### Booking States:

```
pending → accepted → in_progress → completed
  ↓
rejected (terminal)
```

### Payment Flow:

```
1. NEGOTIATION
   ├─ Client creates booking with initial price request
   ├─ Provider receives notification
   └─ Provider sends counter-offer (or accepts)

2. AGREEMENT
   ├─ Both agree on price
   ├─ Client sees "Garantizar" button
   └─ Client authorizes payment (5% Guarantee fee added)

3. EXECUTION
   ├─ Service date arrives
   ├─ Service is performed
   └─ Completion marked by client/provider

4. SETTLEMENT
   └─ Payment is captured (only on completion)

REFUNDS: Auto if provider rejects, or by admin
```

### Payment Service:

```dart
class PaymentService {
  // Client pays: agreed_price + 5% guarantee
  static double clientTotal(double agreedPrice) {
    return agreedPrice * 1.05;
  }

  // Provider receives: agreed_price - 5% commission
  static double providerEarning(double agreedPrice) {
    return agreedPrice * 0.95;
  }
}
```

---

## 📍 Location & Geo-Matching

### Features:

1. **User Location Detection** (Geolocator)
   ```dart
   final position = await Geolocator.getCurrentPosition();
   final userLatlng = LatLng(position.latitude, position.longitude);
   ```

2. **Map Display** (Google Maps)
   ```dart
   GoogleMap(
     initialCameraPosition: CameraPosition(
       target: userLocation,
       zoom: 15,
     ),
     markers: {
       Marker(
         markerId: MarkerId('user'),
         position: userLocation,
       ),
     },
   );
   ```

3. **Request Matching** (SQL)
   ```sql
   -- Show requests in user's province
   SELECT * FROM bookings
   WHERE client_province = user_province
   AND status = 'pending'
   AND provider_id IS NULL;
   ```

---

## 🧪 Testing Strategy

### Unit Tests (40% coverage target)
- Models (serialization, equality)
- Providers (state changes)
- Utils (formatters, validators)

```dart
test('User model has correct toString()', () {
  final user = User(id: '123', email: 'test@ex.com', fullName: 'Test');
  expect(user.toString(), contains('123'));
});
```

### Widget Tests (30% coverage target)
- Screens (layout, interactions)
- Complex widgets (forms, lists)

```dart
testWidgets('LoginScreen shows error on bad password', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.enterText(find.byType(TextField).first, 'wrong');
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  expect(find.byType(SnackBar), findsOneWidget);
});
```

### Integration Tests (20% coverage target)
- Full flows (login → booking → payment)
- Real Supabase interaction (in staging)

```dart
testWidgets('Complete booking flow', (tester) async {
  // Login
  // Search service
  // Make booking
  // Pay
  // Verify completion
});
```

---

## 🔧 Build & Deployment

### Local Development
```bash
flutter run -d chrome          # Web
flutter run -d android         # Mobile
```

### Staging (GitHub Pages)
```bash
flutter build web --release
# Auto-deployed via GitHub Actions
# URL: https://goyachild25-afk.github.io/serviciosya/
```

### Production Mobile
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ipa --release
```

---

## 🚨 Known Issues & Limitations

### 1. Web Rendering Issue
- **Status:** INVESTIGATING
- **Symptom:** App compiles but doesn't render in Chrome
- **Workaround:** Use mobile version for testing

### 2. Real-time Sync on Mobile
- **Status:** MOSTLY FIXED
- **Issue:** RealtimeSubscribeException occasionally occurs
- **Fix:** RLS policy corrections in migration 20260624

### 3. Performance
- **Issue:** Build size ~100MB+ for web
- **Target:** <50MB (requires optimization)

---

## 📊 Database Schema (Key Tables)

### profiles
```sql
id (UUID) - User ID from auth
email (TEXT) - Email address
full_name (TEXT) - Display name
avatar_url (TEXT) - Profile photo
role (ENUM) - 'client' or 'provider'
created_at (TIMESTAMP)
```

### provider_profiles
```sql
id (UUID)
user_id (UUID FK)
full_name (TEXT)
province (TEXT)
phone (TEXT)
is_available (BOOLEAN)
avg_rating (FLOAT)
review_count (INT)
```

### bookings
```sql
id (UUID)
client_id (UUID FK)
provider_id (UUID FK) - NULL if open request
service_name (TEXT)
category_id (TEXT)
status (ENUM) - 'pending', 'accepted', 'completed', 'rejected'
agreed_price (FLOAT) - After negotiation
negotiation_status (TEXT) - 'pending', 'counter_offered', 'agreed'
scheduled_date (TIMESTAMP)
created_at (TIMESTAMP)
```

### chat_messages
```sql
id (UUID)
booking_id (UUID FK)
sender_id (UUID FK)
content (TEXT)
type (TEXT) - 'text', 'offer', 'counter_offer', 'offer_accepted'
is_read (BOOLEAN)
created_at (TIMESTAMP)
```

---

## 🎯 Best Practices

### Code Style
- Use `const` for widgets when possible
- Single responsibility principle
- Immutable models with `@freezed` or `final`

### State Management
- Keep providers small and focused
- Use `ref.watch()` to listen, not `ref.read()`
- Clean up resources in `dispose()`

### Error Handling
- Never silent catch (`catch (_)`)
- Always log errors with context
- Show user-friendly error messages

### Testing
- Test behavior, not implementation
- Use mocks for external services
- Keep tests fast (<100ms ideal)

### Comments
- Only WHY, never WHAT
- Document non-obvious logic
- Update comments when code changes

---

## 📚 References

- **Riverpod:** https://riverpod.dev
- **go_router:** https://pub.dev/packages/go_router
- **Supabase:** https://supabase.com/docs
- **Flutter Best Practices:** https://docs.flutter.dev/testing

---

**Questions?** Contact the development team or review specific FEATURE_*.md docs.
