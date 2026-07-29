class AuthUser {
  final String emailOrPhone;
  final String fullname;
  final String role; // 'admin' or 'customer'

  AuthUser({
    required this.emailOrPhone,
    required this.fullname,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      emailOrPhone: json['email_or_phone'] ?? '',
      fullname: json['fullname'] ?? '',
      role: json['role'] ?? 'customer',
    );
  }

  Map<String, dynamic> toJson() => {
        'email_or_phone': emailOrPhone,
        'fullname': fullname,
        'role': role,
      };

  bool get isAdmin => role == 'admin';
}
