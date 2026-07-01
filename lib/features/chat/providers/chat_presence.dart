import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

/// Estado observable de la presencia del "otro lado" del chat.
///
/// Se alimenta de un channel de Supabase Realtime por reserva. Cada usuario
/// hace track de su propia presencia (`user_id` + `online: true`) y broadcast
/// eventos de typing.
class ChatPresenceState {
  final bool otherOnline;
  final bool otherTyping;

  const ChatPresenceState({
    required this.otherOnline,
    required this.otherTyping,
  });

  static const idle = ChatPresenceState(otherOnline: false, otherTyping: false);

  ChatPresenceState copyWith({bool? otherOnline, bool? otherTyping}) =>
      ChatPresenceState(
        otherOnline: otherOnline ?? this.otherOnline,
        otherTyping: otherTyping ?? this.otherTyping,
      );
}

class ChatPresenceController extends StateNotifier<ChatPresenceState> {
  ChatPresenceController(this.bookingId) : super(ChatPresenceState.idle) {
    _connect();
  }

  final String bookingId;
  RealtimeChannel? _channel;
  Timer? _typingResetTimer;

  Future<void> _connect() async {
    final me = SupabaseService.currentUser?.id;
    if (me == null) return;

    _channel =
        SupabaseService.client.channel('chat:$bookingId', opts: RealtimeChannelConfig(
      self: false,
    ));

    _channel!
      ..onPresenceSync((_) {
        try {
          final state = _channel!.presenceState();
          final others = state
              .where((p) => p.presences.any((pr) {
                    final data = pr.payload;
                    return data['user_id'] != null && data['user_id'] != me;
                  }))
              .toList();
          if (mounted) {
            this.state =
                this.state.copyWith(otherOnline: others.isNotEmpty);
          }
        } catch (_) {}
      })
      ..onBroadcast(
        event: 'typing',
        callback: (payload) {
          final from = payload['user_id'];
          if (from == null || from == me) return;
          _typingResetTimer?.cancel();
          if (mounted) state = state.copyWith(otherTyping: true);
          _typingResetTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) state = state.copyWith(otherTyping: false);
          });
        },
      )
      ..subscribe((status, error) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          try {
            await _channel!.track({'user_id': me, 'online': true});
          } catch (e) {
            if (kDebugMode) debugPrint('presence track failed: $e');
          }
        }
      });
  }

  /// Llamar cada vez que el usuario está escribiendo. El broadcast se envía
  /// a lo más una vez por segundo para no saturar el channel.
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> broadcastTyping() async {
    final me = SupabaseService.currentUser?.id;
    if (me == null || _channel == null) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent).inMilliseconds < 1000) return;
    _lastTypingSent = now;
    try {
      await _channel!.sendBroadcastMessage(
        event: 'typing',
        payload: {'user_id': me},
      );
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    _typingResetTimer?.cancel();
    try {
      if (_channel != null) {
        await SupabaseService.client.removeChannel(_channel!);
      }
    } catch (_) {}
    super.dispose();
  }
}

/// Provider por booking. Al salir de la pantalla se dispose automáticamente
/// y libera el channel de Realtime.
final chatPresenceProvider =
    StateNotifierProvider.autoDispose.family<ChatPresenceController,
        ChatPresenceState, String>(
  (ref, bookingId) => ChatPresenceController(bookingId),
);
