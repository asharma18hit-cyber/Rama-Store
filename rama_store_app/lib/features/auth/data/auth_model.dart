class AuthUser {
  final String? id;
  final String emailOrPhone;
  final String fullname;
  final String role; // 'admin' or 'customer'

  AuthUser({
    this.id,
    required this.emailOrPhone,
    required this.fullname,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? json['uid']?.toString(),
      emailOrPhone: json['email_or_phone'] ?? json['emailOrPhone'] ?? '',
      fullname: json['fullname'] ?? '',
      role: json['role'] ?? 'customer',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email_or_phone': emailOrPhone,
        'fullname': fullname,
        'role': role,
      };

  bool get isAdmin => role == 'admin';
}

