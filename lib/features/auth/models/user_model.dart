enum UserRole { client, provider, admin }

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final String? province;
  final String? city;
  final String? address;
  final DateTime createdAt;
  final bool isVerified;
  final bool isActive;
  final bool emailVerified;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.province,
    this.city,
    this.address,
    required this.createdAt,
    this.isVerified = false,
    this.isActive = true,
    this.emailVerified = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.client,
      ),
      province: json['province'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      emailVerified: json['email_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'role': role.name,
        'province': province,
        'city': city,
        'address': address,
        'created_at': createdAt.toIso8601String(),
        'is_verified': isVerified,
        'is_active': isActive,
        'email_verified': emailVerified,
      };

  UserModel copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? province,
    String? city,
    String? address,
    bool? isVerified,
    bool? isActive,
  }) {
    return UserModel(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role,
      province: province ?? this.province,
      city: city ?? this.city,
      address: address ?? this.address,
      createdAt: createdAt,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
    );
  }
}
