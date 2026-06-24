enum UserRole { user, admin }

enum UserStatus { pending, approved, rejected }

class User {
  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.role = UserRole.user,
    this.status = UserStatus.approved,
  });

  final String id;
  final String email;
  final String? displayName;
  final UserRole role;
  final UserStatus status;

  bool get isAdmin => role == UserRole.admin;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        if (displayName != null) 'displayName': displayName,
        'role': role.name,
        'status': status.name,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String?,
        role: UserRole.values.byName(
          (json['role'] as String?) ?? 'user',
        ),
        status: UserStatus.values.byName(
          (json['status'] as String?) ?? 'approved',
        ),
      );
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final User user;
  final String accessToken;
  final String refreshToken;
}
