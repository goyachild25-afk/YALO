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
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
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
        'type': type.name,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
      };

  bool isMine(String currentUserId) => senderId == currentUserId;
}

enum MessageType { text, image, system }

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

// Demo messages for demo mode
final List<ChatMessage> demoMessages = [
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
    content: 'Perfecto Ana, estaré puntual. ¿Tiene materiales de limpieza o los llevo yo?',
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
];
