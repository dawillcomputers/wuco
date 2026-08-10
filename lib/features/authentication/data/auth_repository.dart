import '../domain/programme_enrolment.dart';
import '../domain/user_profile.dart';
import '../domain/user_role.dart';

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

  Future<void> resendVerification(String email);

  /// Confirms an address from the emailed link.
  Future<UserProfile> verifyEmail(String token);

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

  /// Creates an account on a user's behalf and returns the one-time password
  /// to hand over. The account is flagged [UserProfile.mustChangePassword].
  Future<({UserProfile profile, String temporaryPassword})> adminCreateUser({
    required String email,
    required UserRole role,
    String firstName,
    String lastName,
  });

  Future<void> adminDeleteUser(String userId);

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
