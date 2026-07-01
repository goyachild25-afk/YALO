import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'supabase_service.dart';

/// Servicio que escucha `notifications` en Realtime y muestra un banner
/// flotante cuando llega una nueva. Corresponde a "notificaciones in-app"
/// (distinto de push nativo del OS, que requiere Firebase).
///
/// Uso: envolver el MaterialApp.router.builder con `LiveNotificationsHost`.
class LiveNotificationsHost extends ConsumerStatefulWidget {
  final Widget child;
  const LiveNotificationsHost({super.key, required this.child});

  @override
  ConsumerState<LiveNotificationsHost> createState() =>
      _LiveNotificationsHostState();
}

class _LiveNotificationsHostState extends ConsumerState<LiveNotificationsHost> {
  RealtimeChannel? _channel;
  String? _watchingUserId;

  final _overlayKey = GlobalKey<_LiveOverlayState>();

  @override
  void initState() {
    super.initState();
    // Delayed para que el rebuild inicial esté hecho
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _reconcile());
  }

  void _reconcile() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == _watchingUserId) return;
    _closeChannel();
    _watchingUserId = uid;
    if (uid != null) _openChannel(uid);
  }

  Future<void> _openChannel(String uid) async {
    _channel = SupabaseService.client
        .channel('notifications:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            _showBanner(
              title: data['title'] as String? ?? 'Nueva notificación',
              body: data['body'] as String? ?? '',
              bookingId: data['booking_id'] as String?,
            );
          },
        )
        .subscribe();
  }

  Future<void> _closeChannel() async {
    if (_channel != null) {
      try {
        await SupabaseService.client.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
  }

  void _showBanner({
    required String title,
    required String body,
    String? bookingId,
  }) {
    HapticFeedback.mediumImpact();
    _overlayKey.currentState?.push(
      _LiveMessage(title: title, body: body, bookingId: bookingId),
    );
  }

  @override
  void dispose() {
    _closeChannel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watchear el authState — cuando cambia (login/logout), el widget
    // se re-buildea y _reconcile cierra el channel viejo y abre el nuevo.
    // Sin esto, un logout deja vivo el channel del usuario anterior hasta
    // el próximo rebuild fortuito.
    ref.watch(authStateProvider);
    _reconcile();
    return _LiveOverlay(key: _overlayKey, child: widget.child);
  }
}

class _LiveMessage {
  final String title;
  final String body;
  final String? bookingId;
  const _LiveMessage({
    required this.title,
    required this.body,
    this.bookingId,
  });
}

class _LiveOverlay extends StatefulWidget {
  final Widget child;
  const _LiveOverlay({super.key, required this.child});

  @override
  State<_LiveOverlay> createState() => _LiveOverlayState();
}

class _LiveOverlayState extends State<_LiveOverlay>
    with SingleTickerProviderStateMixin {
  _LiveMessage? _current;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void push(_LiveMessage m) {
    setState(() => _current = m);
    _anim.forward(from: 0);
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      _anim.reverse().whenComplete(() {
        if (mounted) setState(() => _current = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, -0.6),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: _anim, curve: Curves.easeOutBack)),
              child: FadeTransition(
                opacity: _anim,
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.surface,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      final bookingId = _current!.bookingId;
                      _anim.reverse().whenComplete(() {
                        if (mounted) setState(() => _current = null);
                      });
                      if (bookingId != null) {
                        // Deep-link a la vista de la reserva vía chat
                        GoRouter.of(context).push(
                          '/chat/$bookingId?name=&service=&provider=false',
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primaryLighter,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _current!.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _current!.body,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
