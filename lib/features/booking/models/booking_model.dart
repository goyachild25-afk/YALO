enum BookingStatus {
  pending,
  accepted,
  rejected,
  inProgress,
  completed,
  cancelled,
}

enum PaymentStatus { pending, paid, refunded }

class BookingModel {
  final String id;
  final String clientId;
  final String clientName;
  final String? clientAvatarUrl;
  final String providerId;
  final String providerName;
  final String? providerAvatarUrl;
  final String serviceId;
  final String serviceName;
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final DateTime scheduledDate;
  final String? notes;
  final String address;
  final double? agreedPrice;
  final Map<String, dynamic>? formAnswers;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const BookingModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientAvatarUrl,
    required this.providerId,
    required this.providerName,
    this.providerAvatarUrl,
    required this.serviceId,
    required this.serviceName,
    required this.status,
    required this.paymentStatus,
    required this.scheduledDate,
    this.notes,
    required this.address,
    this.agreedPrice,
    this.formAnswers,
    required this.createdAt,
    this.updatedAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      clientName: json['client_name'] as String,
      clientAvatarUrl: json['client_avatar_url'] as String?,
      providerId: json['provider_id'] as String,
      providerName: json['provider_name'] as String,
      providerAvatarUrl: json['provider_avatar_url'] as String?,
      serviceId: json['service_id'] as String,
      serviceName: json['service_name'] as String,
      status: BookingStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => BookingStatus.pending,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == json['payment_status'],
        orElse: () => PaymentStatus.pending,
      ),
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      notes: json['notes'] as String?,
      address: json['address'] as String,
      agreedPrice: (json['agreed_price'] as num?)?.toDouble(),
      formAnswers: json['form_answers'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'client_id': clientId,
        'client_name': clientName,
        'client_avatar_url': clientAvatarUrl,
        'provider_id': providerId,
        'provider_name': providerName,
        'provider_avatar_url': providerAvatarUrl,
        'service_id': serviceId,
        'service_name': serviceName,
        'status': status.name,
        'payment_status': paymentStatus.name,
        'scheduled_date': scheduledDate.toIso8601String(),
        'notes': notes,
        'address': address,
        'agreed_price': agreedPrice,
        'form_answers': formAnswers,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  String get statusLabel {
    switch (status) {
      case BookingStatus.pending:
        return 'Pendiente';
      case BookingStatus.accepted:
        return 'Aceptado';
      case BookingStatus.rejected:
        return 'Rechazado';
      case BookingStatus.inProgress:
        return 'En progreso';
      case BookingStatus.completed:
        return 'Completado';
      case BookingStatus.cancelled:
        return 'Cancelado';
    }
  }
}
