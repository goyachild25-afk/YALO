# ServiciosYa - Technical Audit & Improvement Plan
**Date:** June 24, 2026  
**Status:** COMPREHENSIVE OVERHAUL IN PROGRESS

---

## 🔴 CRITICAL ISSUES

### 1. RLS Security Gap
**Status:** FIXED (migr created: `20260624_fix_rls_security.sql`)
- **Issue:** Typo "authenticcated" in dispatch policy allows universal read access
- **Impact:** Users can see other users' profiles, bookings, and messages
- **Files:** `supabase/migrations/20260619_fix_dispatch_accept_and_notify.sql` (LINE 11)
- **Fix:** Migrated to restrictive RLS policies by user_id and booking relationships

### 2. Flutter Web Rendering Failure
**Status:** INVESTIGATING
- **Issue:** App compiles but doesn't render in Chrome (stuck on "Waiting for debug connection")
- **Impact:** Web version cannot be tested or deployed
- **Evidence:** `flutter build web` succeeds, but `flutter run -d chrome` hangs
- **Root Cause:** Unknown (possible: Chrome debugging bridge issue, or JavaScript initialization)
- **Workaround:** Mobile version works; web can be served from build/web but doesn't load
- **Next Steps:** 
  - Check `main.dart` for web-specific initialization issues
  - Review JavaScript console errors in build/web/index.html
  - Test with simplified minimal example
  - Consider if google_maps_flutter_web or other plugins have issues

---

## 🟡 HIGH PRIORITY ISSUES

### 3. Error Handling
- **Issue:** Many try-catch blocks silently fail (`.catch((_) {})`  everywhere)
- **Impact:** Makes debugging difficult, hides real errors
- **Files:** `chat_screen.dart`, `provider_dashboard_screen.dart`, `onboarding_provider.dart`
- **Fix:** Add proper error logging and user feedback

### 4. Null Safety
- **Issue:** Many null-coalescing operations (`?? ''`, `?? 0`) without validation
- **Impact:** Could lead to unexpected behavior if not carefully handled
- **Example:** `r['client_province'] as String? ?? ''` - if `null` becomes empty string, filters may not work correctly

### 5. Real-time Subscription Errors
- **Issue:** Known "RealtimeSubscribeException" on mobile
- **Status:** Partially fixed with RLS policy changes
- **Files:** Migration `20260619_fix_realtime_rls.sql` applied but not verified
- **Fix:** Apply new RLS security migration once tested

---

## 🟠 MEDIUM PRIORITY IMPROVEMENTS

### 6. Chat UI/UX
- **Issue:** Message ordering (reversed) but interface could be cleaner
- **Current:** Messages display bottom-to-top (latest at bottom)
- **Good:** Background color is warm (cream)
- **Needs:** 
  - Better offer button styling (shouldn't obstruct send button)
  - More contrast on send button
  - Price label clarity

### 7. Navigation Flow
- **Issue:** `SplashScreen` handles role-based routing but could be cleaner
- **Status:** Fixed in previous session
- **Files:** `splash_screen.dart`, `app_router.dart`
- **Status:** Tests needed to verify behavior

### 8. Responsive Design
- **Issue:** Mobile experience may have layout issues
- **Evidence:** User reported "el boton de oferta obstruye boton de enviar"
- **Status:** Partially fixed but needs QA

---

## 📊 CODE QUALITY ISSUES

### 9. Missing Tests
- **Test Coverage:** ~0%
- **Critical Paths Without Tests:**
  - Authentication flow (login, signup, role-based routing)
  - Booking creation and acceptance
  - Payment flow
  - Chat messaging
  - Real-time sync

### 10. Missing Documentation
- **Missing Docs:**
  - Architecture overview
  - API/Database schema documentation
  - Setup guide for local development
  - Deployment instructions
  - Environment configuration guide

### 11. State Management
- **Current:** Riverpod with StateProvider, StreamProvider, StateNotifierProvider
- **Issue:** Mix of approaches could be cleaner
- **Example:** `demoModeProvider` is global state but some logic duplicated in screens

### 12. Dependency Updates
- **98 packages** have newer versions available
- **Status:** Needs careful review before updating
- **Critical Packages to Watch:**
  - flutter_riverpod 2.6.1 → 3.3.2 (major version)
  - go_router 14.8.1 → 17.3.0 (multiple major versions behind)

---

## 🔧 SPECIFIC CODE IMPROVEMENTS

### Issue: Silent Catches in `onboarding_provider.dart`
```dart
try {
    final profile = await SupabaseService.client
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    if (profile != null) {
      await prefs.setBool('$_kOnboardingDonePrefix$userId', true);
      return true;
    }
  } catch (_) {}  // ← SILENT CATCH - SHOULD LOG
  return false;
```

**Fix:** Add error logging
```dart
catch (e) {
  debugPrint('isOnboardingComplete error: $e');
}
```

### Issue: No Error Feedback in Chat
**File:** `chat_screen.dart:147-153`
```dart
} catch (e) {
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al enviar: $e')),
      // ← Good, but error logging missing
    );
  }
}
```

**Fix:** Add to logger/Sentry/Firebase Crashlytics

### Issue: Possible NPE in Provider Dashboard
**File:** `provider_dashboard_screen.dart:348`
```dart
final services = await ref.read(myProviderServicesProvider.future);
final categories = services.map((s) => s.categoryName.toLowerCase()).toList();
```

**Issue:** If `s.categoryName` is null, `.toLowerCase()` will throw  
**Fix:** Add null check

---

## ✅ IMPROVEMENTS TO IMPLEMENT

### Phase 1: Critical (This Session)
- [ ] Apply RLS security migration to Supabase
- [ ] Debug and fix Flutter web rendering
- [ ] Fix error handling (add logging)
- [ ] Add null safety checks

### Phase 2: High Priority (This Week)
- [ ] Create unit tests for auth flow
- [ ] Create integration tests for booking flow
- [ ] Add proper error logging (Sentry/Firebase)
- [ ] Update dependencies carefully

### Phase 3: Medium Priority (This Month)
- [ ] Write architecture documentation
- [ ] Create API documentation
- [ ] Improve UI responsiveness
- [ ] Optimize build size

---

## 📈 METRICS TO TRACK

| Metric | Current | Target |
|--------|---------|--------|
| Test Coverage | 0% | 80%+ |
| Web App Rendering | ❌ Broken | ✅ Working |
| Mobile Tests | None | Full E2E |
| Documentation Pages | 0 | 10+ |
| RLS Security | ❌ Broken | ✅ Fixed |
| Build Size (Web) | ~100MB+ | <50MB |
| Page Load Time | Unknown | <2s |

---

## 📝 NEXT IMMEDIATE ACTIONS

1. **Apply RLS Migration** → TEST in Supabase immediately
2. **Fix Null Safety** → Audit all `.map()` chains
3. **Add Error Logging** → Implement basic Firebase/Sentry logging
4. **Fix Flutter Web** → Deep dive into JavaScript console errors
5. **Write First Test** → Simple auth unit test to establish testing pattern

**Owner:** Senior Engineer (me)  
**Timeline:** TODAY (life is too short to postpone)
