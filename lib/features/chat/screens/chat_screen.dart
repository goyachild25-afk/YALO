import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/demo_provider.dart';
import '../../../core/services/payment_service.dart';
import '../models/chat_model.dart';

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, bookingId) {
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) {
    return Stream.value(demoMessages
        .where((m) => m.bookingId == bookingId)
        .toList());
  }
  return SupabaseService.client
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .eq('booking_id', bookingId)
      .order('created_at')
      .map((data) => data.map((j) => ChatMessage.fromJson(j)).toList());
});

/// Escucha el estado de negociación del booking en tiempo real (para el banner de pago)
final _bookingStateProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, bookingId) {
  return SupabaseService.client
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('id', bookingId)
      .map((rows) => rows.isNotEmpty ? rows.first : null);
});

/// Decodifica JSON de forma segura — usado por burbujas de oferta y el banner
Map<String, dynamic> _decodeJson(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return {};
}

class ChatScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String otherUserName;
  final String serviceName;
  /// true cuando el usuario actual es el prestador del servicio
  final bool isProvider;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.otherUserName,
    required this.serviceName,
    this.isProvider = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  // Demo: lista local mutable para simular el envío
  final List<ChatMessage> _demoLocalMessages = [];

  @override
  void initState() {
    super.initState();
    _demoLocalMessages.addAll(
      demoMessages.where((m) => m.bookingId == widget.bookingId),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Enviar mensaje de texto ───────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textCtrl.clear();

    final isDemo = ref.read(demoModeProvider);
    if (isDemo) {
      final user = ref.read(demoUserProvider)!;
      setState(() {
        _demoLocalMessages.add(ChatMessage(
          id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
          bookingId: widget.bookingId,
          senderId: user.id,
          senderName: user.fullName,
          content: text,
          type: MessageType.text,
          createdAt: DateTime.now(),
        ));
      });
      _scrollToBottom();
      setState(() => _sending = false);
      return;
    }

    try {
      final user = SupabaseService.currentUser!;
      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();

      await SupabaseService.client.from('chat_messages').insert({
        'booking_id': widget.bookingId,
        'sender_id': user.id,
        'sender_name': profile['full_name'],
        'content': text,
        'type': 'text',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Prestador: enviar oferta de precio ───────────────────────────────────────
  Future<void> _showSendOfferDialog() async {
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OfferBottomSheet(
        priceCtrl: priceCtrl,
        descCtrl: descCtrl,
        title: 'Enviar oferta de precio',
        actionLabel: 'Enviar oferta',
        actionColor: AppColors.primary,
      ),
    );

    if (!mounted) return;
    if (confirmed != true) {
      priceCtrl.dispose();
      descCtrl.dispose();
      return;
    }

    final price = double.tryParse(priceCtrl.text.trim());
    if (price == null || price <= 0) {
      priceCtrl.dispose();
      descCtrl.dispose();
      return;
    }
    final description = descCtrl.text.trim();
    priceCtrl.dispose();
    descCtrl.dispose();

    await _insertNegotiationMessage(
      type: MessageType.offer,
      content: jsonEncode({'price': price, 'description': description}),
      bookingUpdates: {
        'negotiation_status': 'offer_sent',
        'provider_offer': price,
        if (description.isNotEmpty) 'offer_description': description,
      },
    );
  }

  // ── Cliente: responder oferta ─────────────────────────────────────────────────
  Future<void> _acceptOffer(double price) async {
    await _insertNegotiationMessage(
      type: MessageType.offerAccepted,
      content: jsonEncode({'price': price, 'by': 'client'}),
      bookingUpdates: {
        'negotiation_status': 'agreed',
        'agreed_price': price,
      },
    );
  }

  Future<void> _sendCounterOffer(double offerPrice) async {
    final priceCtrl = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OfferBottomSheet(
        priceCtrl: priceCtrl,
        descCtrl: null,
        title: 'Tu contraoferta',
        actionLabel: 'Enviar contraoferta',
        actionColor: AppColors.info,
        hintText:
            'La oferta fue RD\$${offerPrice.toStringAsFixed(0)}. Ingresa tu precio.',
      ),
    );

    if (!mounted) return;
    if (confirmed != true) { priceCtrl.dispose(); return; }

    final price = double.tryParse(priceCtrl.text.trim());
    priceCtrl.dispose();
    if (price == null || price <= 0) return;

    await _insertNegotiationMessage(
      type: MessageType.counterOffer,
      content: jsonEncode({'price': price}),
      bookingUpdates: {
        'negotiation_status': 'counter_offer_sent',
        'client_counter_offer': price,
      },
    );
  }

  // ── Prestador: responder contraoferta ────────────────────────────────────────
  Future<void> _acceptCounterOffer(double price) async {
    await _insertNegotiationMessage(
      type: MessageType.offerAccepted,
      content: jsonEncode({'price': price, 'by': 'provider'}),
      bookingUpdates: {
        'negotiation_status': 'agreed',
        'agreed_price': price,
      },
    );
  }

  Future<void> _rejectOffer() async {
    await _insertNegotiationMessage(
      type: MessageType.offerRejected,
      content: jsonEncode({}),
      bookingUpdates: {'negotiation_status': 'offer_rejected'},
    );
  }

  // ── Helper común para mensajes de negociación ─────────────────────────────────
  Future<void> _insertNegotiationMessage({
    required MessageType type,
    required String content,
    required Map<String, dynamic> bookingUpdates,
  }) async {
    setState(() => _sending = true);

    final isDemo = ref.read(demoModeProvider);
    if (isDemo) {
      final user = ref.read(demoUserProvider)!;
      if (mounted) {
        setState(() {
          _demoLocalMessages.add(ChatMessage(
            id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
            bookingId: widget.bookingId,
            senderId: user.id,
            senderName: user.fullName,
            content: content,
            type: type,
            createdAt: DateTime.now(),
          ));
          _sending = false;
        });
        _scrollToBottom();
      }
      return;
    }

    try {
      final user = SupabaseService.currentUser!;
      final profile = await SupabaseService.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();

      // Insertar mensaje en chat
      await SupabaseService.client.from('chat_messages').insert({
        'booking_id': widget.bookingId,
        'sender_id': user.id,
        'sender_name': profile['full_name'],
        'content': content,
        'type': ChatMessage.typeToDb(type),
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Actualizar estado de negociación en bookings (requiere migración v2)
      try {
        await SupabaseService.client.from('bookings').update({
          ...bookingUpdates,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.bookingId);
      } catch (_) {
        // Columnas de negociación no existen aún — la migración v2 no se ha ejecutado.
        // El chat sigue funcionando; solo el estado del booking no se actualiza.
      }

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Banner de pago (solo cliente, cuando el precio está acordado) ────────────
  Widget _buildPayBanner(double agreedPrice) {
    // El cliente reserva el precio base + 5 % de Garantía ServiciosYa
    // La tarjeta se AUTORIZA ahora; el cobro real ocurre al completar el servicio
    final total = PaymentService.clientTotal(agreedPrice);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        border: Border.symmetric(
          horizontal: BorderSide(
            color: AppColors.success.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.success, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¡Precio acordado! 🎉',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'Reserva RD\$${total.toStringAsFixed(0)} · '
                  'Solo se cobra al completar',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
            onPressed: () => context.push(
              '/payment'
              '?bookingId=${widget.bookingId}'
              '&amount=${total.toStringAsFixed(2)}'
              '&service=${Uri.encodeComponent(widget.serviceName)}'
              '&provider=${Uri.encodeComponent(widget.otherUserName)}'
              '&currency=dop',
            ),
            child: const Text('Garantizar 🔒'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDemo = ref.watch(demoModeProvider);
    final currentUserId = isDemo
        ? ref.watch(demoUserProvider)?.id ?? ''
        : SupabaseService.currentUser?.id ?? '';

    // ── Detectar precio acordado ──────────────────────────────────────────────
    // Real: leer negotiation_status del booking en tiempo real
    // Demo: buscar el último mensaje offerAccepted en los mensajes locales
    double? agreedPrice;
    if (!isDemo) {
      final bookingAsync = ref.watch(_bookingStateProvider(widget.bookingId));
      final booking = bookingAsync.valueOrNull;
      if (booking?['negotiation_status'] == 'agreed') {
        agreedPrice = (booking!['agreed_price'] as num?)?.toDouble();
      }
    } else {
      for (final msg in _demoLocalMessages.reversed) {
        if (msg.type == MessageType.offerAccepted) {
          final data = _decodeJson(msg.content);
          agreedPrice = (data['price'] as num?)?.toDouble();
          break;
        }
      }
    }
    // El banner de pago solo lo ve el CLIENTE (nunca el prestador)
    // Usar variable local non-null para que la type promotion funcione en el widget tree
    final double? payPrice =
        (!widget.isProvider && agreedPrice != null && agreedPrice > 0)
            ? agreedPrice
            : null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        elevation: 1,
        shadowColor: Colors.black12,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLighter,
              child: Text(
                widget.otherUserName.isNotEmpty
                    ? widget.otherUserName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.serviceName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Botón de oferta en AppBar (solo para prestadores)
            if (widget.isProvider)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.local_offer_outlined, size: 20),
                  onPressed: _showSendOfferDialog,
                  tooltip: 'Enviar oferta de precio',
                ),
              ),
          ],
        ),
      ),
      body: Container(
        color: const Color(0xFFFAF8F3), // Crema cálido y acogedor
        child: Column(
          children: [
            Expanded(
              child: isDemo
                  ? _buildDemoMessages(currentUserId)
                  : _buildRealtimeMessages(currentUserId),
            ),
            // Banner de pago: aparece en cuanto el precio queda acordado
            if (payPrice != null) _buildPayBanner(payPrice),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoMessages(String currentUserId) {
    if (_demoLocalMessages.isEmpty) return _buildEmptyChat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      itemCount: _demoLocalMessages.length,
      itemBuilder: (_, i) {
        final msg = _demoLocalMessages[_demoLocalMessages.length - 1 - i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _MessageBubble(
            message: msg,
            isMine: msg.isMine(currentUserId),
            isProvider: widget.isProvider,
            onAcceptOffer: _acceptOffer,
            onCounterOffer: _sendCounterOffer,
            onAcceptCounterOffer: _acceptCounterOffer,
            onRejectOffer: _rejectOffer,
          ),
        );
      },
    );
  }

  Widget _buildRealtimeMessages(String currentUserId) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.bookingId));
    return messagesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (messages) {
        if (messages.isEmpty) return _buildEmptyChat();
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final msg = messages[messages.length - 1 - i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _MessageBubble(
                message: msg,
                isMine: msg.isMine(currentUserId),
                isProvider: widget.isProvider,
                onAcceptOffer: _acceptOffer,
                onCounterOffer: _sendCounterOffer,
                onAcceptCounterOffer: _acceptCounterOffer,
                onRejectOffer: _rejectOffer,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline,
                size: 40, color: AppColors.textHint),
          ),
          const SizedBox(height: 16),
          const Text(
            'Inicia la conversación',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coordina los detalles y el precio del servicio aquí',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          10, 12, 8, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: const Color(0xFFFAF8F3), // Mismo fondo acogedor
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje...',
                hintStyle: const TextStyle(fontSize: 14, color: AppColors.textHint),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE0DDD5), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFFE0DDD5), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: _textCtrl.text.isEmpty
                    ? LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.5), AppColors.primary.withValues(alpha: 0.3)])
                    : AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: _textCtrl.text.isEmpty
                    ? []
                    : [BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )],
              ),
              child: _sending
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: const CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Icon(
                      _textCtrl.text.isEmpty ? Icons.add_rounded : Icons.send_rounded,
                      color: Colors.white,
                      size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BURBUJA DE MENSAJE (texto + oferta + contraoferta + aceptado + rechazado)
// ═════════════════════════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool isProvider;
  final void Function(double price) onAcceptOffer;
  final void Function(double offerPrice) onCounterOffer;
  final void Function(double price) onAcceptCounterOffer;
  final VoidCallback onRejectOffer;

  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.isProvider,
    required this.onAcceptOffer,
    required this.onCounterOffer,
    required this.onAcceptCounterOffer,
    required this.onRejectOffer,
  });

  @override
  Widget build(BuildContext context) {
    // Tipos especiales: renderizado centrado
    if (message.type == MessageType.offerAccepted ||
        message.type == MessageType.offerRejected) {
      return _buildStatusMessage(context);
    }

    // Oferta / contraoferta: burbuja especial
    if (message.type == MessageType.offer ||
        message.type == MessageType.counterOffer) {
      return _buildOfferBubble(context);
    }

    // Mensaje de texto normal
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryLighter,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                    border: isMine
                        ? null
                        : Border.all(color: AppColors.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isMine ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DateFormat('HH:mm').format(message.createdAt),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          if (isMine) const SizedBox(width: 6),
        ],
      ),
    );
  }

  // ── Burbuja de oferta / contraoferta ─────────────────────────────────────────
  Widget _buildOfferBubble(BuildContext context) {
    final isOffer = message.type == MessageType.offer;
    final Map<String, dynamic> data = _decodeJson(message.content);
    final price = (data['price'] as num?)?.toDouble() ?? 0;
    final description = data['description'] as String? ?? '';

    // ¿Quién puede accionar?
    // Oferta → solo puede accionar el cliente (si no es el prestador)
    // Contraoferta → solo puede accionar el prestador
    final canAct = isOffer ? !isProvider : isProvider;

    final Color cardColor = isOffer ? AppColors.primaryLighter : AppColors.infoLight;
    final Color borderColor = isOffer ? AppColors.primary : AppColors.info;
    final Color textColor = isOffer ? AppColors.primaryDark : AppColors.info;
    final IconData icon = isOffer
        ? Icons.local_offer_outlined
        : Icons.reply_outlined;
    final String header = isOffer
        ? '💰 Oferta de precio'
        : '↩️ Contraoferta del cliente';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                children: [
                  Icon(icon, color: textColor, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    header,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textColor),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textHint),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Precio
              Text(
                'RD\$${price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4),
                ),
              ],

              // Botones de acción (solo si la parte correcta los ve)
              if (canAct) ...[
                const SizedBox(height: 12),
                if (isOffer) ...[
                  // Cliente: aceptar o contraofertar
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.info,
                            side: const BorderSide(color: AppColors.info),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.reply, size: 14),
                          label: const Text('Contraofertar',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () => onCounterOffer(price),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.check, size: 14,
                              color: Colors.white),
                          label: const Text('Aceptar',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.white)),
                          onPressed: () => onAcceptOffer(price),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Prestador: aceptar o rechazar contraoferta
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Rechazar',
                              style: TextStyle(fontSize: 12)),
                          onPressed: onRejectOffer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.check, size: 14,
                              color: Colors.white),
                          label: const Text('Aceptar contraoferta',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.white)),
                          onPressed: () => onAcceptCounterOffer(price),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Mensaje de estado (aceptado / rechazado) ──────────────────────────────────
  Widget _buildStatusMessage(BuildContext context) {
    final isAccepted = message.type == MessageType.offerAccepted;
    final Map<String, dynamic> data = _decodeJson(message.content);
    final price = (data['price'] as num?)?.toDouble();
    final by = data['by'] as String?;
    final byLabel = by == 'client' ? 'el cliente' : 'el prestador';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isAccepted ? AppColors.successLight : AppColors.errorLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isAccepted
                  ? AppColors.success.withValues(alpha: 0.4)
                  : AppColors.error.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAccepted ? Icons.handshake_outlined : Icons.cancel_outlined,
                size: 16,
                color: isAccepted ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isAccepted
                      ? price != null
                          ? '✅ Precio acordado: RD\$${price.toStringAsFixed(0)} — aceptado por $byLabel'
                          : '✅ Precio acordado'
                      : '❌ Oferta rechazada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isAccepted ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET PARA ENVIAR OFERTA / CONTRAOFERTA
// ═════════════════════════════════════════════════════════════════════════════
class _OfferBottomSheet extends StatelessWidget {
  final TextEditingController priceCtrl;
  final TextEditingController? descCtrl;
  final String title;
  final String actionLabel;
  final Color actionColor;
  final String? hintText;

  const _OfferBottomSheet({
    required this.priceCtrl,
    this.descCtrl,
    required this.title,
    required this.actionLabel,
    required this.actionColor,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (hintText != null) ...[
            const SizedBox(height: 4),
            Text(hintText!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 16),

          // Campo de precio
          TextField(
            controller: priceCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Precio (RD\$)',
              prefixIcon: const Icon(Icons.attach_money,
                  color: AppColors.primary),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),

          if (descCtrl != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText:
                    'Detalla qué incluye el precio, materiales, tiempo estimado...',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
