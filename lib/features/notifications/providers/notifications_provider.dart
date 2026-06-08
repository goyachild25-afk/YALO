import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../models/notification_model.dart';

// ── Lista de notificaciones (real: Supabase stream / demo: hardcoded) ────────
final notificationsProvider =
    StreamProvider<List<AppNotification>>((ref) async* {
  final isDemo = ref.watch(demoModeProvider);

  if (isDemo) {
    final demoUser = ref.watch(demoUserProvider);
    final userId = demoUser?.id ?? '';
    final filtered =
        demoNotifications.where((n) => n.userId == userId).toList();
    yield filtered;
    return;
  }

  final user = SupabaseService.currentUser;
  if (user == null) {
    yield [];
    return;
  }

  // Carga inicial
  final initial = await SupabaseService.client
      .from('notifications')
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(50);

  yield (initial as List<dynamic>)
      .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
      .toList();

  // Stream en tiempo real para nuevas notificaciones
  await for (final _ in SupabaseService.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(50)) {
    final rows = await SupabaseService.client
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    yield (rows as List<dynamic>)
        .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
        .toList();
  }
});

// ── Cantidad de no leídas (para el badge) ────────────────────────────────────
final unreadCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider);
  return notifs.value?.where((n) => !n.isRead).length ?? 0;
});

// ── Controller para marcar como leídas ───────────────────────────────────────
final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, AsyncValue<void>>((ref) {
  return NotificationsController(ref);
});

class NotificationsController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  NotificationsController(this._ref) : super(const AsyncValue.data(null));

  Future<void> markAllRead() async {
    final isDemo = _ref.read(demoModeProvider);
    if (isDemo) return; // En demo no se persiste

    final user = SupabaseService.currentUser;
    if (user == null) return;

    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', user.id)
        .eq('is_read', false);
  }

  Future<void> markRead(String notifId) async {
    final isDemo = _ref.read(demoModeProvider);
    if (isDemo) return;

    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true}).eq('id', notifId);
  }
}
