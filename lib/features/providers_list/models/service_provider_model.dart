enum PricingType { fixed, quote }

// ─── Niveles de prestador ─────────────────────────────────────────────────────
enum ProviderLevel { newLevel, destacado, experto, elite }

extension ProviderLevelX on ProviderLevel {
  String get dbValue => switch (this) {
        ProviderLevel.newLevel => 'new',
        ProviderLevel.destacado => 'destacado',
        ProviderLevel.experto   => 'experto',
        ProviderLevel.elite     => 'elite',
      };

  String get label => switch (this) {
        ProviderLevel.newLevel => 'Nuevo',
        ProviderLevel.destacado => 'Destacado',
        ProviderLevel.experto   => 'Experto',
        ProviderLevel.elite     => 'Elite',
      };

  String get emoji => switch (this) {
        ProviderLevel.newLevel => '🌱',
        ProviderLevel.destacado => '⭐',
        ProviderLevel.experto   => '🏆',
        ProviderLevel.elite     => '💎',
      };

  /// Commission percentage (platform fee)
  double get commission => switch (this) {
        ProviderLevel.newLevel => 0.15,
        ProviderLevel.destacado => 0.12,
        ProviderLevel.experto   => 0.10,
        ProviderLevel.elite     => 0.07,
      };

  String get commissionLabel => '${(commission * 100).toStringAsFixed(0)}%';

  /// Min jobs to reach this level
  int get minJobs => switch (this) {
        ProviderLevel.newLevel => 0,
        ProviderLevel.destacado => 10,
        ProviderLevel.experto   => 50,
        ProviderLevel.elite     => 100,
      };

  /// Max jobs for this level (null = no cap)
  int? get maxJobs => switch (this) {
        ProviderLevel.newLevel => 9,
        ProviderLevel.destacado => 49,
        ProviderLevel.experto   => 99,
        ProviderLevel.elite     => null,
      };

  static ProviderLevel fromDb(String? value) => switch (value) {
        'destacado' => ProviderLevel.destacado,
        'experto'   => ProviderLevel.experto,
        'elite'     => ProviderLevel.elite,
        _           => ProviderLevel.newLevel,
      };

  static ProviderLevel fromJobs(int jobs) {
    if (jobs >= 100) return ProviderLevel.elite;
    if (jobs >= 50)  return ProviderLevel.experto;
    if (jobs >= 10)  return ProviderLevel.destacado;
    return ProviderLevel.newLevel;
  }

  ProviderLevel? get next => switch (this) {
        ProviderLevel.newLevel  => ProviderLevel.destacado,
        ProviderLevel.destacado => ProviderLevel.experto,
        ProviderLevel.experto   => ProviderLevel.elite,
        ProviderLevel.elite     => null,
      };
}

class ServiceProviderModel {
  final String id;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String bio;
  final double rating;
  final int reviewCount;
  final int completedJobs;
  final List<ProviderService> services;
  final String province;
  final String city;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final bool isAvailable;
  final bool isVerified;
  final List<String> photoUrls;
  final DateTime memberSince;
  final ProviderLevel level;

  const ServiceProviderModel({
    required this.id,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    required this.bio,
    required this.rating,
    required this.reviewCount,
    required this.completedJobs,
    required this.services,
    required this.province,
    required this.city,
    this.latitude,
    this.longitude,
    this.distanceKm,
    required this.isAvailable,
    required this.isVerified,
    required this.photoUrls,
    required this.memberSince,
    this.level = ProviderLevel.newLevel,
  });

  factory ServiceProviderModel.fromJson(Map<String, dynamic> json) {
    return ServiceProviderModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? 0,
      completedJobs: json['completed_jobs'] as int? ?? 0,
      services: (json['services'] as List<dynamic>?)
              ?.map((s) => ProviderService.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      province: json['province'] as String? ?? '',
      city: json['city'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      isAvailable: json['is_available'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      photoUrls: (json['photo_urls'] as List<dynamic>?)
              ?.map((p) => p as String)
              .toList() ??
          [],
      memberSince: DateTime.parse(json['member_since'] as String? ??
          DateTime.now().toIso8601String()),
      level: ProviderLevelX.fromDb(json['level'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'bio': bio,
        'rating': rating,
        'review_count': reviewCount,
        'completed_jobs': completedJobs,
        'services': services.map((s) => s.toJson()).toList(),
        'province': province,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'is_available': isAvailable,
        'is_verified': isVerified,
        'photo_urls': photoUrls,
        'member_since': memberSince.toIso8601String(),
      };

  String get ratingFormatted => rating.toStringAsFixed(1);

  String get locationLabel => '$city, $province';
}

class ProviderService {
  final String id;
  final String categoryId;
  final String categoryName;
  final PricingType pricingType;
  final double? fixedPrice;
  final String? priceDescription;
  final List<ServiceFormField>? formFields;

  const ProviderService({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.pricingType,
    this.fixedPrice,
    this.priceDescription,
    this.formFields,
  });

  factory ProviderService.fromJson(Map<String, dynamic> json) {
    return ProviderService(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      pricingType: PricingType.values.firstWhere(
        (e) => e.name == json['pricing_type'],
        orElse: () => PricingType.fixed,
      ),
      fixedPrice: (json['fixed_price'] as num?)?.toDouble(),
      priceDescription: json['price_description'] as String?,
      formFields: (json['form_fields'] as List<dynamic>?)
          ?.map((f) => ServiceFormField.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_id': categoryId,
        'category_name': categoryName,
        'pricing_type': pricingType.name,
        'fixed_price': fixedPrice,
        'price_description': priceDescription,
        'form_fields': formFields?.map((f) => f.toJson()).toList(),
      };

  String get priceLabel {
    if (pricingType == PricingType.fixed && fixedPrice != null) {
      return '\$${fixedPrice!.toStringAsFixed(0)}';
    }
    return 'Cotización';
  }
}

enum FormFieldType { text, number, select, multiSelect }

class ServiceFormField {
  final String id;
  final String label;
  final String? hint;
  final FormFieldType type;
  final bool required;
  final List<String>? options;

  const ServiceFormField({
    required this.id,
    required this.label,
    this.hint,
    required this.type,
    required this.required,
    this.options,
  });

  factory ServiceFormField.fromJson(Map<String, dynamic> json) {
    return ServiceFormField(
      id: json['id'] as String,
      label: json['label'] as String,
      hint: json['hint'] as String?,
      type: FormFieldType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => FormFieldType.text,
      ),
      required: json['required'] as bool? ?? true,
      options: (json['options'] as List<dynamic>?)?.map((o) => o as String).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'hint': hint,
        'type': type.name,
        'required': required,
        'options': options,
      };
}

class ReviewModel {
  final String id;
  final String clientId;
  final String clientName;
  final String? clientAvatarUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientAvatarUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      clientName: json['client_name'] as String,
      clientAvatarUrl: json['client_avatar_url'] as String?,
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
