class ChatMessage {
  final String id;
  final String bookingId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      senderId: json['sender_id'] as String,
      senderName: json['sender_name'] as String,
      content: json['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == (json['type'] as String?)?.replaceAll('_', ''),
        orElse: () => MessageType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => MessageType.text,
        ),
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'sender_id': senderId,
        'sender_name': senderName,
        'content': content,
        'type': typeToDb(type),
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
      };

  // Público para permitir su uso desde chat_screen.dart al insertar mensajes
  static String typeToDb(MessageType t) {
    switch (t) {
      case MessageType.text: return 'text';
      case MessageType.image: return 'image';
      case MessageType.system: return 'system';
      case MessageType.offer: return 'offer';
      case MessageType.counterOffer: return 'counter_offer';
      case MessageType.offerAccepted: return 'offer_accepted';
      case MessageType.offerRejected: return 'offer_rejected';
    }
  }

  bool isMine(String currentUserId) => senderId == currentUserId;
}

enum MessageType {
  text,
  image,
  system,
  // ── Tipos de negociación (CAMBIO 3) ─────────────────────────────────────────
  offer,          // Prestador envía oferta → content: {"price": 2500, "description": "..."}
  counterOffer,   // Cliente envía contraoferta → content: {"price": 2000}
  offerAccepted,  // Alguna de las partes acepta → content: {"price": 2000, "by": "client"}
  offerRejected,  // Alguna de las partes rechaza → content: {}
}

class ChatConversation {
  final String bookingId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String serviceName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ChatConversation({
    required this.bookingId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.serviceName,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });
}

// ─── Mensajes demo ───────────────────────────────────────────────────────────
final List<ChatMessage> demoMessages = [
  // book-p001: conversación de limpieza del hogar
  ChatMessage(
    id: 'msg-001',
    bookingId: 'book-p001',
    senderId: 'demo-client-001',
    senderName: 'Ana Rodríguez',
    content: 'Hola! Confirmo la reserva para mañana a las 9am.',
    type: MessageType.text,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    isRead: true,
  ),
  ChatMessage(
    id: 'msg-002',
    bookingId: 'book-p001',
    senderId: 'demo-provider-001',
    senderName: 'Carlos Méndez',
    content:
        'Perfecto Ana, estaré puntual. ¿Tiene materiales de limpieza o los llevo yo?',
    type: MessageType.text,
    createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
    isRead: true,
  ),
  ChatMessage(
    id: 'msg-003',
    bookingId: 'book-p001',
    senderId: 'demo-client-001',
    senderName: 'Ana Rodríguez',
    content: 'Por favor tráigalos usted, yo no tengo todos.',
    type: MessageType.text,
    createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
    isRead: true,
  ),
  ChatMessage(
    id: 'msg-004',
    bookingId: 'book-p001',
    senderId: 'demo-provider-001',
    senderName: 'Carlos Méndez',
    content: 'Con gusto, los incluyo. Nos vemos mañana 👍',
    type: MessageType.text,
    createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
    isRead: false,
  ),

  // book-p002: negociación de precio (demo para mostrar flujo CAMBIO 3)
  ChatMessage(
    id: 'msg-010',
    bookingId: 'book-p002',
    senderId: 'client-009',
    senderName: 'Jorge Ramírez',
    content:
        'Hola Carlos, necesito limpieza completa para la oficina de 80m². ¿Cuándo puedes y cuánto cobras?',
    type: MessageType.text,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    isRead: true,
  ),
  ChatMessage(
    id: 'msg-011',
    bookingId: 'book-p002',
    senderId: 'demo-provider-001',
    senderName: 'Carlos Méndez',
    // Oferta de precio: JSON con monto y descripción
    content:
        '{"price":3500,"description":"Limpieza profunda 80m²: pisos, sanitarios, escritorios y ventanas. Incluyo todos los materiales."}',
    type: MessageType.offer,
    createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
    isRead: true,
  ),
  ChatMessage(
    id: 'msg-012',
    bookingId: 'book-p002',
    senderId: 'client-009',
    senderName: 'Jorge Ramírez',
    // Contraoferta del cliente
    content: '{"price":3000}',
    type: MessageType.counterOffer,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    isRead: true,
  ),
  ChatMessage(
    id: 'msg-013',
    bookingId: 'book-p002',
    senderId: 'demo-provider-001',
    senderName: 'Carlos Méndez',
    // Oferta aceptada por el prestador
    content: '{"price":3000,"by":"provider"}',
    type: MessageType.offerAccepted,
    createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
    isRead: true,
  ),
  ChatMessage(
    id: 'msg-014',
    bookingId: 'book-p002',
    senderId: 'demo-provider-001',
    senderName: 'Carlos Méndez',
    content: 'Perfecto Jorge, acepto los RD\$3,000. ¿Confirmamos para el jueves?',
    type: MessageType.text,
    createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 40)),
    isRead: false,
  ),
];
