/// Lifecycle state of an account, independent of its role.
enum AccountStatus {
  active('ACTIVE', 'Active'),
  pending('PENDING', 'Pending'),
  pendingApproval('PENDING_APPROVAL', 'Awaiting approval'),
  suspended('SUSPENDED', 'Suspended'),
  disabled('DISABLED', 'Disabled');

  const AccountStatus(this.wireName, this.label);

  final String wireName;
  final String label;

  static AccountStatus fromWireName(String? value) =>
      AccountStatus.values.firstWhere(
        (status) => status.wireName == value,
        orElse: () => AccountStatus.pending,
      );

  /// Whether the account may hold a session at all.
  bool get canSignIn => this == AccountStatus.active;

  /// Message shown when [canSignIn] is false. Deliberately free of internal
  /// detail.
  String? get blockedMessage => switch (this) {
    AccountStatus.active => null,
    AccountStatus.pending =>
      'Your account is not active yet. Please verify your email address.',
    AccountStatus.pendingApproval =>
      'Your account is awaiting administrative approval.',
    AccountStatus.suspended =>
      'Your account has been temporarily suspended. Please contact WEA support.',
    AccountStatus.disabled =>
      'Your account is currently disabled. Please contact WEA support.',
  };
}
