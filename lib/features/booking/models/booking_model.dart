enum BookingStatus {
  pending,
  accepted,
  rejected,
  inProgress,
  completed,
  cancelled,
}

enum PaymentStatus { pending, paid, refunded }

// ─── Estado de negociación de precio (CAMBIO 3) ───────────────────────────────
enum NegotiationStatus {
  noOffer,           // Sin oferta todavía
  offerSent,         // Prestador envió oferta de precio
  counterOfferSent,  // Cliente envió contraoferta (solo 1 vez permitida)
  agreed,            // Precio acordado entre ambas partes
  offerRejected,     // Oferta/contraoferta rechazada
}

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

  // ── Campos de negociación (CAMBIO 3) ─────────────────────────────────────────
  final NegotiationStatus negotiationStatus;
  final double? providerOffer;         // Oferta enviada por el prestador
  final double? clientCounterOffer;    // Contraoferta del cliente
  final String? offerDescription;     // Descripción adjunta a la oferta
  final String? serviceDescription;   // Descripción del trabajo por realizar
  final List<String>? servicePhotos;  // URLs de fotos del trabajo

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
    this.negotiationStatus = NegotiationStatus.noOffer,
    this.providerOffer,
    this.clientCounterOffer,
    this.offerDescription,
    this.serviceDescription,
    this.servicePhotos,
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
      serviceId: json['service_id'] as String? ?? '',
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
      // Campos de negociación — graceful fallback si la migración v2 no se ha ejecutado
      negotiationStatus: NegotiationStatus.values.firstWhere(
        (e) => e.name == _camelToSnakeMap[json['negotiation_status'] as String?],
        orElse: () {
          final raw = json['negotiation_status'] as String?;
          return NegotiationStatus.values.firstWhere(
            (e) => e.name == raw,
            orElse: () => NegotiationStatus.noOffer,
          );
        },
      ),
      providerOffer: (json['provider_offer'] as num?)?.toDouble(),
      clientCounterOffer: (json['client_counter_offer'] as num?)?.toDouble(),
      offerDescription: json['offer_description'] as String?,
      serviceDescription: json['service_description'] as String?,
      servicePhotos: (json['service_photos'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  // Mapa de snake_case DB → enum name
  static const _camelToSnakeMap = <String, String>{
    'no_offer': 'noOffer',
    'offer_sent': 'offerSent',
    'counter_offer_sent': 'counterOfferSent',
    'agreed': 'agreed',
    'offer_rejected': 'offerRejected',
  };

  static String negotiationStatusToDb(NegotiationStatus s) {
    switch (s) {
      case NegotiationStatus.noOffer: return 'no_offer';
      case NegotiationStatus.offerSent: return 'offer_sent';
      case NegotiationStatus.counterOfferSent: return 'counter_offer_sent';
      case NegotiationStatus.agreed: return 'agreed';
      case NegotiationStatus.offerRejected: return 'offer_rejected';
    }
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
        'negotiation_status': negotiationStatusToDb(negotiationStatus),
        'provider_offer': providerOffer,
        'client_counter_offer': clientCounterOffer,
        'offer_description': offerDescription,
        'service_description': serviceDescription,
        'service_photos': servicePhotos,
      };

  String get statusLabel {
    switch (status) {
      case BookingStatus.pending: return 'Pendiente';
      case BookingStatus.accepted: return 'Aceptado';
      case BookingStatus.rejected: return 'Rechazado';
      case BookingStatus.inProgress: return 'En progreso';
      case BookingStatus.completed: return 'Completado';
      case BookingStatus.cancelled: return 'Cancelado';
    }
  }

  String get negotiationLabel {
    switch (negotiationStatus) {
      case NegotiationStatus.noOffer: return 'Sin oferta de precio';
      case NegotiationStatus.offerSent: return 'Oferta enviada';
      case NegotiationStatus.counterOfferSent: return 'Contraoferta del cliente';
      case NegotiationStatus.agreed: return 'Precio acordado';
      case NegotiationStatus.offerRejected: return 'Oferta rechazada';
    }
  }
}
