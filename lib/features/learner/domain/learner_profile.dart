import '../../authentication/domain/user_profile.dart';

/// Who may see a learner's professional record.
///
/// Defaults to [network] rather than [public]: nothing about a learner becomes
/// publicly visible without them choosing it.
enum ProfileVisibility {
  private('Private', 'Only you can see your profile.'),
  network('WEA network', 'Visible to WEA faculty and fellow professionals.'),
  public('Public', 'Visible to anyone with your profile link.');

  const ProfileVisibility(this.label, this.description);
  final String label;
  final String description;
}

/// The learner-specific half of an account.
///
/// Identity (name, email, role) stays on [UserProfile], which authentication
/// owns; this holds the professional detail the learner area adds on top, so
/// neither model has to know how the other is stored.
class LearnerProfile {
  const LearnerProfile({
    required this.userId,
    this.professionalTitle = '',
    this.organisation = '',
    this.bio = '',
    this.expertise = const [],
    this.linkedInUrl,
    this.websiteUrl,
    this.city,
    this.visibility = ProfileVisibility.network,
  });

  final String userId;
  final String professionalTitle;
  final String organisation;
  final String bio;
  final List<String> expertise;
  final String? linkedInUrl;
  final String? websiteUrl;
  final String? city;
  final ProfileVisibility visibility;

  LearnerProfile copyWith({
    String? professionalTitle,
    String? organisation,
    String? bio,
    List<String>? expertise,
    String? linkedInUrl,
    String? websiteUrl,
    String? city,
    ProfileVisibility? visibility,
  }) => LearnerProfile(
    userId: userId,
    professionalTitle: professionalTitle ?? this.professionalTitle,
    organisation: organisation ?? this.organisation,
    bio: bio ?? this.bio,
    expertise: expertise ?? this.expertise,
    linkedInUrl: linkedInUrl ?? this.linkedInUrl,
    websiteUrl: websiteUrl ?? this.websiteUrl,
    city: city ?? this.city,
    visibility: visibility ?? this.visibility,
  );
}

/// How complete a learner's profile is, and what is still outstanding.
///
/// Named rather than a bare percentage so the UI can tell the learner what to
/// add instead of just nagging them with a number.
class ProfileCompletion {
  const ProfileCompletion({required this.total, required this.missing});

  final int total;
  final List<String> missing;

  int get completed => total - missing.length;
  double get fraction => total == 0 ? 1 : completed / total;
  int get percent => (fraction * 100).round();
  bool get isComplete => missing.isEmpty;

  /// Derived from both halves of the account, since either can be incomplete.
  factory ProfileCompletion.of(UserProfile account, LearnerProfile learner) {
    bool filled(String? value) => value != null && value.trim().isNotEmpty;

    final checks = <String, bool>{
      'First name': filled(account.firstName),
      'Last name': filled(account.lastName),
      'Phone number': filled(account.phone),
      'Country': filled(account.country),
      'Profile photo': filled(account.avatarUrl),
      'Professional title': filled(learner.professionalTitle),
      'Organisation': filled(learner.organisation),
      'Professional biography': filled(learner.bio),
      'Areas of expertise': learner.expertise.isNotEmpty,
      'LinkedIn profile': filled(learner.linkedInUrl),
    };

    return ProfileCompletion(
      total: checks.length,
      missing: [
        for (final entry in checks.entries)
          if (!entry.value) entry.key,
      ],
    );
  }
}
