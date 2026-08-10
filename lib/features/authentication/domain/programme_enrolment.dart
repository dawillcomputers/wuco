/// How an enrolment was paid for.
enum EnrolmentPayment {
  pending('PENDING', 'Payment pending'),
  paid('PAID', 'Paid'),

  /// Granted by a Super Admin without payment. Recorded explicitly rather than
  /// faking a payment, so the waiver stays auditable.
  waived('WAIVED', 'Payment waived');

  const EnrolmentPayment(this.wireName, this.label);
  final String wireName;
  final String label;

  static EnrolmentPayment fromWireName(String? value) =>
      EnrolmentPayment.values.firstWhere(
        (payment) => payment.wireName == value,
        orElse: () => EnrolmentPayment.pending,
      );
}

/// A learner's place on one programme.
///
/// Accounts are reusable: enrolling in a second programme adds another record
/// against the same user rather than requiring a new account.
class ProgrammeEnrolment {
  const ProgrammeEnrolment({
    required this.id,
    required this.userId,
    required this.programmeId,
    required this.payment,
    this.grantedBy,
    this.createdAt,
  });

  final String id;
  final String userId;
  final String programmeId;
  final EnrolmentPayment payment;

  /// Super Admin who granted a waived place, when applicable.
  final String? grantedBy;

  final DateTime? createdAt;

  bool get isWaived => payment == EnrolmentPayment.waived;

  factory ProgrammeEnrolment.fromMap(Map<String, dynamic> map) =>
      ProgrammeEnrolment(
        id: map['id'] as String? ?? '',
        userId: map['user_id'] as String? ?? '',
        programmeId: map['programme_id'] as String? ?? '',
        payment: EnrolmentPayment.fromWireName(map['payment_status'] as String?),
        grantedBy: map['granted_by'] as String?,
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'user_id': userId,
    'programme_id': programmeId,
    'payment_status': payment.wireName,
    'granted_by': grantedBy,
  };
}
