enum NotificationType {
  bookingAccepted,
  bookingRejected,
  bookingCompleted,
  newBookingRequest,
  newReview,
  requestExpired,
  bookingReminder,
  disputeResolved,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final String? bookingId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.bookingId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.bookingAccepted,
      ),
      title: json['title'] as String,
      body: json['body'] as String,
      bookingId: json['booking_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      bookingId: bookingId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

// Notificaciones demo para mostrar en modo demo
final List<AppNotification> demoNotifications = [
  AppNotification(
    id: 'notif-001',
    userId: 'demo-client',
    type: NotificationType.bookingAccepted,
    title: '✅ Solicitud aceptada',
    body: 'Carlos Méndez aceptó tu solicitud de Limpieza del hogar para el 20/06/2025.',
    bookingId: 'book-001',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
  AppNotification(
    id: 'notif-002',
    userId: 'demo-client',
    type: NotificationType.bookingCompleted,
    title: '🎉 Servicio completado',
    body: 'El servicio de Limpieza del hogar ha sido marcado como completado. ¡Deja tu reseña!',
    bookingId: 'book-p001',
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  AppNotification(
    id: 'notif-003',
    userId: 'demo-provider',
    type: NotificationType.newBookingRequest,
    title: '🔔 Nueva solicitud',
    body: 'Ana Rodríguez solicita Limpieza del hogar para el 25/06/2025.',
    bookingId: 'book-003',
    isRead: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  AppNotification(
    id: 'notif-004',
    userId: 'demo-provider',
    type: NotificationType.newReview,
    title: '⭐ Nueva reseña recibida',
    body: 'Ana Rodríguez te dejó una reseña de 5 estrellas. ¡Sigue así!',
    bookingId: null,
    isRead: true,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];
