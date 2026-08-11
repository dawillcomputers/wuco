/// Models for programme registration and the payment configuration behind it.
library;

String _text(Map<String, dynamic> map, String key) =>
    (map[key] as String?)?.trim() ?? '';

bool _bool(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value == true || value == 1 || value == '1' || value == 'true';
}

enum RegistrationFieldType {
  text,
  textarea,
  select,
  checkbox,
  date,
  number;

  static RegistrationFieldType parse(String value) => switch (value) {
    'TEXTAREA' => RegistrationFieldType.textarea,
    'SELECT' => RegistrationFieldType.select,
    'CHECKBOX' => RegistrationFieldType.checkbox,
    'DATE' => RegistrationFieldType.date,
    'NUMBER' => RegistrationFieldType.number,
    _ => RegistrationFieldType.text,
  };
}

/// A question asked at registration. Defined by a Super Admin, not in code.
class RegistrationField {
  const RegistrationField({
    required this.id,
    required this.fieldKey,
    required this.label,
    required this.type,
    required this.options,
    required this.helpText,
    required this.required,
    this.prefill,
  });

  final String id;
  final String fieldKey;
  final String label;
  final RegistrationFieldType type;
  final List<String> options;
  final String helpText;
  final bool required;

  /// The applicant's answer from an earlier registration, where there was one.
  final String? prefill;

  factory RegistrationField.fromMap(Map<String, dynamic> map) =>
      RegistrationField(
        id: _text(map, 'id'),
        fieldKey: _text(map, 'field_key'),
        label: _text(map, 'label'),
        type: RegistrationFieldType.parse(_text(map, 'field_type')),
        options: [
          for (final option in (map['options'] as List? ?? const []))
            '$option',
        ],
        helpText: _text(map, 'help_text'),
        required: _bool(map, 'required'),
        prefill: map['prefill'] == null ? null : '${map['prefill']}'.trim(),
      );
}

/// What registration still needs from this applicant.
///
/// The whole point of this model: `known` is what WEA already holds and will
/// reuse; only [missingProfile] and unanswered [fields] are actually asked.
class RegistrationContext {
  const RegistrationContext({
    required this.known,
    required this.missingProfile,
    required this.fields,
    required this.profileComplete,
  });

  final Map<String, String> known;
  final List<String> missingProfile;
  final List<RegistrationField> fields;
  final bool profileComplete;

  String get firstName => known['first_name'] ?? '';

  /// True when this applicant has registered before, so the form can greet
  /// them rather than treating them as new.
  bool get isReturning =>
      profileComplete && fields.any((field) => (field.prefill ?? '').isNotEmpty);

  factory RegistrationContext.fromMap(Map<String, dynamic> map) =>
      RegistrationContext(
        known: {
          for (final entry in (map['known'] as Map? ?? const {}).entries)
            '${entry.key}': '${entry.value ?? ''}',
        },
        missingProfile: [
          for (final key in (map['missing_profile'] as List? ?? const []))
            '$key',
        ],
        fields: [
          for (final field in (map['fields'] as List? ?? const []))
            RegistrationField.fromMap(Map<String, dynamic>.from(field as Map)),
        ],
        profileComplete: _bool(map, 'profile_complete'),
      );
}

enum PaymentMethodKind { bankTransfer, gateway, invoice, offline }

/// A way to pay, configured by a Super Admin. No provider is compiled in.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.slug,
    required this.kind,
    required this.title,
    required this.instructions,
    required this.currency,
    this.bankName = '',
    this.accountName = '',
    this.accountNumber = '',
    this.sortCode = '',
    this.swiftCode = '',
    this.gatewayProvider = '',
    this.gatewayCheckoutUrl = '',
  });

  final String id;
  final String slug;
  final PaymentMethodKind kind;
  final String title;
  final String instructions;
  final String currency;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String sortCode;
  final String swiftCode;
  final String gatewayProvider;
  final String gatewayCheckoutUrl;

  bool get isBankTransfer => kind == PaymentMethodKind.bankTransfer;
  bool get hasBankDetails =>
      accountNumber.isNotEmpty && accountNumber != 'To be configured';

  /// Bank fields worth showing, skipping any the academy has not filled in.
  List<(String, String)> get bankDetails => [
    if (bankName.isNotEmpty) ('Bank', bankName),
    if (accountName.isNotEmpty) ('Account name', accountName),
    if (accountNumber.isNotEmpty) ('Account number', accountNumber),
    if (sortCode.isNotEmpty) ('Sort code', sortCode),
    if (swiftCode.isNotEmpty) ('SWIFT / BIC', swiftCode),
  ];

  factory PaymentMethod.fromMap(Map<String, dynamic> map) => PaymentMethod(
    id: _text(map, 'id'),
    slug: _text(map, 'slug'),
    kind: switch (_text(map, 'kind')) {
      'GATEWAY' => PaymentMethodKind.gateway,
      'INVOICE' => PaymentMethodKind.invoice,
      'OFFLINE' => PaymentMethodKind.offline,
      _ => PaymentMethodKind.bankTransfer,
    },
    title: _text(map, 'title'),
    instructions: _text(map, 'instructions'),
    currency: _text(map, 'currency'),
    bankName: _text(map, 'bank_name'),
    accountName: _text(map, 'account_name'),
    accountNumber: _text(map, 'account_number'),
    sortCode: _text(map, 'sort_code'),
    swiftCode: _text(map, 'swift_code'),
    gatewayProvider: _text(map, 'gateway_provider'),
    gatewayCheckoutUrl: _text(map, 'gateway_checkout_url'),
  );
}

enum RegistrationStatus {
  submitted('Submitted'),
  awaitingPayment('Awaiting payment'),
  paid('Payment received'),
  confirmed('Confirmed'),
  waitlisted('Waitlisted'),
  cancelled('Cancelled'),
  declined('Not accepted');

  const RegistrationStatus(this.label);
  final String label;

  static RegistrationStatus parse(String value) => switch (value) {
    'AWAITING_PAYMENT' => RegistrationStatus.awaitingPayment,
    'PAID' => RegistrationStatus.paid,
    'CONFIRMED' => RegistrationStatus.confirmed,
    'WAITLISTED' => RegistrationStatus.waitlisted,
    'CANCELLED' => RegistrationStatus.cancelled,
    'DECLINED' => RegistrationStatus.declined,
    _ => RegistrationStatus.submitted,
  };

  String get wireName => switch (this) {
    RegistrationStatus.submitted => 'SUBMITTED',
    RegistrationStatus.awaitingPayment => 'AWAITING_PAYMENT',
    RegistrationStatus.paid => 'PAID',
    RegistrationStatus.confirmed => 'CONFIRMED',
    RegistrationStatus.waitlisted => 'WAITLISTED',
    RegistrationStatus.cancelled => 'CANCELLED',
    RegistrationStatus.declined => 'DECLINED',
  };
}

/// A submitted application.
class RegistrationRecord {
  const RegistrationRecord({
    required this.id,
    required this.reference,
    required this.programmeTitle,
    required this.programmeSlug,
    required this.status,
    required this.currency,
    required this.createdAt,
    this.amount,
    this.applicantEmail = '',
    this.applicantName = '',
    this.reviewNote = '',
    this.answers = const {},
  });

  final String id;
  final String reference;
  final String programmeTitle;
  final String programmeSlug;
  final RegistrationStatus status;
  final String currency;
  final DateTime? createdAt;
  final double? amount;
  final String applicantEmail;
  final String applicantName;
  final String reviewNote;
  final Map<String, String> answers;

  factory RegistrationRecord.fromMap(Map<String, dynamic> map) {
    final first = _text(map, 'first_name');
    final last = _text(map, 'last_name');
    return RegistrationRecord(
      id: _text(map, 'id'),
      reference: _text(map, 'reference'),
      programmeTitle: _text(map, 'programme_title'),
      programmeSlug: _text(map, 'programme_slug'),
      status: RegistrationStatus.parse(_text(map, 'status')),
      currency: _text(map, 'currency'),
      createdAt: DateTime.tryParse(_text(map, 'created_at')),
      amount: (map['amount'] as num?)?.toDouble(),
      applicantEmail: _text(map, 'applicant_email'),
      applicantName: '$first $last'.trim(),
      reviewNote: _text(map, 'review_note'),
      answers: {
        for (final entry in (map['answers'] as Map? ?? const {}).entries)
          '${entry.key}': '${entry.value ?? ''}',
      },
    );
  }
}
