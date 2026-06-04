class User {
  const User({
    required this.id,
    required this.phone,
    this.displayName,
  });

  final String id;
  final String phone;
  final String? displayName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        if (displayName != null) 'displayName': displayName,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        phone: json['phone'] as String,
        displayName: json['displayName'] as String?,
      );
}

class AuthSession {
  const AuthSession({required this.user, required this.token});

  final User user;
  final String token;
}
