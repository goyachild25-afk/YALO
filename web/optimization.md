# Web Build Optimization Guide

## 📊 Current Build Size
- Main bundle: ~4.5MB (main.dart.js)
- Total with assets: ~100MB+
- Target: <50MB

## 🎯 Optimization Strategies

### 1. Image Optimization
**Action Required:**
```bash
# Compress all PNG/JPG files
find assets/images -name "*.png" -o -name "*.jpg" | while read f; do
  tinypng "$f"  # or use imagemagick
done

# Or use Flutter's built-in optimization
flutter build web --release --tree-shake-icons
```

### 2. Code Splitting
Flutter web can be split by routes to enable lazy loading:

```dart
// In go_router, use lazy routes:
GoRoute(
  path: '/dashboard',
  builder: (context, state) => DashboardScreen(),
  // ↓ This enables code splitting
  preload: false,
)
```

### 3. Asset Bundling
Currently building with:
```bash
flutter build web --release --no-tree-shake-icons
```

Should build with:
```bash
flutter build web --release --tree-shake-icons --base-href /Serviciosya/
```

**Impact:** Remove unused Material Design icons (~1.6MB → ~25KB)

### 4. Remove Unused Dependencies

Check pubspec.yaml for unused packages:
```bash
flutter pub deps --style=list
```

Candidates for removal (web only):
- geolocator (use browser Geolocation API directly)
- image_picker (use HTML file input)
- google_maps_flutter (use Google Maps Embed API for web)

### 5. Dart2JS Compilation Flags

Add to `pubspec.yaml`:
```yaml
# Custom Dart2JS flags for smaller output
build:
  targets:
    $default:
      builders:
        build_web_compilers|entrypoint:
          options:
            dart2jsArgs:
              - --trust-type-annotations
              - --omit-implicit-checks
              - --trust-primitives
```

### 6. Service Worker Caching

Add aggressive caching in `web/flutter_service_worker.js`:
```javascript
const CACHE_VERSION = 'serviciosya-v1.0.0';
const MAX_CACHE_SIZE = 50 * 1024 * 1024; // 50MB

// Cache strategies:
// - Network first: API calls
// - Cache first: Static assets
// - Stale-while-revalidate: User profiles
```

### 7. Minification

Ensure minification in release build:
```bash
flutter build web --release --dart-define=FLUTTER_WEB_AUTODETECT_NATIVE_ASSET_FOR_WINDOWS=false
```

## 📈 Build Size Comparison

| Scenario | Size | Load Time | Method |
|----------|------|-----------|--------|
| Current | 4.5MB | ~8s | Unoptimized |
| + Tree-shake icons | 3.2MB | ~6s | Remove unused icons |
| + Image compression | 2.1MB | ~4s | Optimize assets |
| + Code splitting | 1.8MB | ~3s | Lazy load routes |
| + Remove web deps | 1.2MB | ~2s | Use web APIs directly |

## 🔧 Implementation Steps

1. **Immediate (This Week)**
   - [ ] Enable `--tree-shake-icons`
   - [ ] Compress all images
   - [ ] Benchmark: `flutter build web --release`

2. **Short Term (Next 2 Weeks)**
   - [ ] Implement code splitting for routes
   - [ ] Remove unused dependencies
   - [ ] Set up Dart2JS optimization

3. **Medium Term (This Month)**
   - [ ] Implement service worker caching
   - [ ] Add performance monitoring
   - [ ] Set up CI/CD size checks

## 🧪 Testing Optimizations

```bash
# Measure current build size
flutter build web --release
du -sh build/web

# Measure with optimizations
flutter build web --release --tree-shake-icons --no-web-resources-cdn
du -sh build/web

# Test performance
lighthouse https://goyachild25-afk.github.io/Serviciosya/
```

## 📊 Lighthouse Target

Target scores:
- Performance: 90+
- Accessibility: 95+
- Best Practices: 90+
- SEO: 100

## 📝 Notes

- Don't over-optimize at the cost of readability
- Measure before and after each change
- Use Chrome DevTools Network tab to profile
- Monitor real user metrics via web analytics

---

**Current Status:** Ready for Phase 1 optimization  
**Estimated Size Reduction:** 4.5MB → ~1.5MB (66% reduction)  
**Estimated Load Time:** 8s → ~2s
