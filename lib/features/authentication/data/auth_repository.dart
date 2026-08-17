import '../domain/account_status.dart';
import '../domain/programme_enrolment.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';

/// The sign-in details the office can pass to somebody.
///
/// Two things, because they are used differently: the temporary password is
/// read out over a telephone, and the link is pasted into a message. Both are
/// emailed as well, so the account holder has them even if the office forgets
/// to pass anything on.
///
/// The link works once and expires an hour after it was issued. That is the
/// point of it — a link forwarded on, or left sitting in an inbox, stops being
/// a way into somebody's account.
class IssuedCredentials {
  const IssuedCredentials({
    required this.email,
    required this.temporaryPassword,
    this.setPasswordUrl = '',
    this.expiresAt,
  });

  final String email;
  final String temporaryPassword;
  final String setPasswordUrl;
  final DateTime? expiresAt;

  bool get hasLink => setPasswordUrl.isNotEmpty;

  factory IssuedCredentials.fromMap(Map<String, dynamic> map, String email) =>
      IssuedCredentials(
        email: email,
        temporaryPassword: '${map['temporary_password'] ?? ''}',
        setPasswordUrl: '${map['set_password_url'] ?? ''}',
        expiresAt: DateTime.tryParse('${map['set_password_expires_at'] ?? ''}'),
      );
}

/// A sign-in provider this deployment is configured for.
///
/// The client id comes from the API rather than being compiled in, so a
/// deployment that has not configured Google simply offers no Google button
/// — instead of offering one that fails when it is pressed.
class SocialProvider {
  const SocialProvider({
    required this.provider,
    required this.label,
    required this.clientId,
  });

  /// `GOOGLE` or `APPLE`, as the API names it.
  final String provider;
  final String label;
  final String clientId;

  factory SocialProvider.fromMap(Map<String, dynamic> map) => SocialProvider(
    provider: '${map['provider'] ?? ''}',
    label: '${map['label'] ?? ''}',
    clientId: '${map['client_id'] ?? ''}',
  );
}

/// Everything the application may ask of the authentication backend.
///
/// The interface exists so the UI never talks to Supabase directly: swapping
/// [InMemoryAuthRepository] for [SupabaseAuthRepository] is a configuration
/// change, not a rewrite.
abstract interface class AuthRepository {
  /// Emits on every session change, including restoration at start-up.
  Stream<UserProfile?> get changes;

  /// The stored session's profile, or null. Called once on launch.
  Future<UserProfile?> restoreSession();

  Future<UserProfile> signIn({required String email, required String password});

  /// The providers this deployment can actually complete a sign-in with, and
  /// the client id each needs. Empty when none is configured — which is why
  /// the interface asks rather than assuming Google is available.
  Future<List<SocialProvider>> socialProviders();

  /// Exchanges a provider's ID token for a WEA session.
  ///
  /// The token is verified by the API against the provider's own public keys.
  /// Nothing here decides who somebody is; it only carries the proof.
  Future<UserProfile> signInWithProvider({
    required String provider,
    required String idToken,
  });

  /// Registers a new account. [role] is ignored unless it is self-assignable —
  /// privilege escalation is refused at this boundary, not just hidden in UI.
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? country,
    UserRole role = UserRole.applicant,
  });

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// Completes a reset started from an emailed link.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });


  /// Confirms an address from the emailed link.

  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? country,
    String? avatarUrl,
  });

  // --- Super Admin surface -------------------------------------------------
  // Each of these re-checks the caller's role inside the implementation.

  Future<List<UserProfile>> listUsers();

  /// Creates an account on a user's behalf and returns the details to hand
  /// over. The account is flagged [UserProfile.mustChangePassword].
  Future<({UserProfile profile, IssuedCredentials credentials})> adminCreateUser({
    required String email,
    required UserRole role,
    String firstName,
    String lastName,
  });

  /// Resets somebody's password for them, for the person who cannot reach
  /// their email or who is on the telephone now.
  ///
  /// Every existing session is dropped, so a stolen one cannot outlive the
  /// reset, and the account must choose a new password before doing anything.
  Future<IssuedCredentials> adminResetPassword(String userId, String email);

  Future<void> adminDeleteUser(String userId);

  /// Suspends, disables or reactivates an account.
  ///
  /// Separate from [adminSetRole] because they answer different questions:
  /// what somebody may do, and whether they may do anything at all.
  Future<UserProfile> adminSetStatus({
    required String userId,
    required AccountStatus status,
  });

  Future<UserProfile> adminSetRole({
    required String userId,
    required UserRole role,
  });

  Future<List<ProgrammeEnrolment>> listEnrolments({String? userId});

  /// Places a learner on a programme. A Super Admin may waive payment.
  Future<ProgrammeEnrolment> enrol({
    required String userId,
    required String programmeId,
    bool waivePayment = false,
  });
}
