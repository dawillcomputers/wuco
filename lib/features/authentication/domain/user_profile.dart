import 'account_status.dart';
import 'user_role.dart';

/// A WEA account as the application sees it. Holds no credentials.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.phone,
    this.country,
    this.avatarUrl,
    this.role = UserRole.applicant,
    this.status = AccountStatus.pending,
    this.emailVerified = false,
    this.mustChangePassword = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? country;
  final String? avatarUrl;
  final UserRole role;
  final AccountStatus status;
  final bool emailVerified;

  /// Set when an administrator issued a temporary password. The router forces
  /// such users to /change-password before anything else.
  final bool mustChangePassword;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? email : name;
  }

  String get initials {
    final first = firstName.trim();
    final last = lastName.trim();
    if (first.isEmpty && last.isEmpty) {
      return email.isEmpty ? '?' : email[0].toUpperCase();
    }
    final buffer = StringBuffer();
    if (first.isNotEmpty) buffer.write(first[0]);
    if (last.isNotEmpty) buffer.write(last[0]);
    return buffer.toString().toUpperCase();
  }

  UserProfile copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? country,
    String? avatarUrl,
    UserRole? role,
    AccountStatus? status,
    bool? emailVerified,
    bool? mustChangePassword,
    DateTime? updatedAt,
  }) => UserProfile(
    id: id,
    email: email,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    phone: phone ?? this.phone,
    country: country ?? this.country,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    role: role ?? this.role,
    status: status ?? this.status,
    emailVerified: emailVerified ?? this.emailVerified,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: map['id'] as String? ?? '',
    email: map['email'] as String? ?? '',
    firstName: map['first_name'] as String? ?? '',
    lastName: map['last_name'] as String? ?? '',
    phone: map['phone'] as String?,
    country: map['country'] as String?,
    avatarUrl: map['avatar_url'] as String?,
    role: UserRole.fromWireName(map['role'] as String?),
    status: AccountStatus.fromWireName(map['status'] as String?),
    emailVerified: map['email_verified'] as bool? ?? false,
    mustChangePassword: map['must_change_password'] as bool? ?? false,
    createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? ''),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'phone': phone,
    'country': country,
    'avatar_url': avatarUrl,
    'role': role.wireName,
    'status': status.wireName,
    'email_verified': emailVerified,
    'must_change_password': mustChangePassword,
  };
}
