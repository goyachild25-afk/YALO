enum DisputeType {
  serviceNotCompleted,   // Servicio no completado
  fraudOrScam,           // Fraude o estafa
  propertyDamage,        // Daño a la propiedad
  inappropriateBehavior, // Conducta inapropiada
  noShow,                // No se presentó
  paymentIssue,          // Problema con el pago
  other,                 // Otro
}

enum DisputeStatus {
  open,       // Abierta
  inReview,   // En revisión
  resolved,   // Resuelta
  closed,     // Cerrada
}

class DisputeModel {
  final String id;
  final String bookingId;
  final String reporterId;
  final String reporterName;
  final String reportedId;
  final String reportedName;
  final DisputeType type;
  final String description;
  final List<String> evidenceUrls;
  final DisputeStatus status;
  final String? adminNotes;
  final String? resolution;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const DisputeModel({
    required this.id,
    required this.bookingId,
    required this.reporterId,
    required this.reporterName,
    required this.reportedId,
    required this.reportedName,
    required this.type,
    required this.description,
    required this.evidenceUrls,
    required this.status,
    this.adminNotes,
    this.resolution,
    required this.createdAt,
    this.resolvedAt,
  });

  String get typeLabel {
    switch (type) {
      case DisputeType.serviceNotCompleted:
        return 'Servicio no completado';
      case DisputeType.fraudOrScam:
        return 'Fraude o estafa';
      case DisputeType.propertyDamage:
        return 'Daño a la propiedad';
      case DisputeType.inappropriateBehavior:
        return 'Conducta inapropiada';
      case DisputeType.noShow:
        return 'No se presentó';
      case DisputeType.paymentIssue:
        return 'Problema con el pago';
      case DisputeType.other:
        return 'Otro motivo';
    }
  }

  String get statusLabel {
    switch (status) {
      case DisputeStatus.open:
        return 'Abierta';
      case DisputeStatus.inReview:
        return 'En revisión';
      case DisputeStatus.resolved:
        return 'Resuelta';
      case DisputeStatus.closed:
        return 'Cerrada';
    }
  }
}
