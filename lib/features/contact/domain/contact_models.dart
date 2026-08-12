/// Enquiries sent to the academy office, and the replies to them.
library;

String _text(Map<String, dynamic> map, String key) =>
    (map[key] as String?)?.trim() ?? '';

enum EnquiryStatus {
  isNew('New'),
  read('Read'),
  replied('Replied'),
  closed('Closed');

  const EnquiryStatus(this.label);
  final String label;

  static EnquiryStatus parse(String value) => switch (value) {
    'READ' => EnquiryStatus.read,
    'REPLIED' => EnquiryStatus.replied,
    'CLOSED' => EnquiryStatus.closed,
    _ => EnquiryStatus.isNew,
  };

  String get wireName => switch (this) {
    EnquiryStatus.isNew => 'NEW',
    EnquiryStatus.read => 'READ',
    EnquiryStatus.replied => 'REPLIED',
    EnquiryStatus.closed => 'CLOSED',
  };
}

/// One message in an enquiry thread.
class EnquiryReply {
  const EnquiryReply({
    required this.id,
    required this.body,
    required this.fromAcademy,
    required this.authorName,
    this.createdAt,
  });

  final String id;
  final String body;

  /// True for an academy reply, false for the sender's own follow-up. Recorded
  /// at the time rather than inferred from the author's current role.
  final bool fromAcademy;
  final String authorName;
  final DateTime? createdAt;

  factory EnquiryReply.fromMap(Map<String, dynamic> map) => EnquiryReply(
    id: _text(map, 'id'),
    body: _text(map, 'body'),
    fromAcademy: map['from_academy'] == true || map['from_academy'] == 1,
    authorName: _text(map, 'author_name'),
    createdAt: DateTime.tryParse(_text(map, 'created_at')),
  );
}

/// An enquiry and its conversation.
class Enquiry {
  const Enquiry({
    required this.id,
    required this.reference,
    required this.name,
    required this.email,
    required this.subject,
    required this.message,
    required this.status,
    required this.replies,
    this.phone = '',
    this.organisation = '',
    this.createdAt,
    this.hasAccount = false,
  });

  final String id;
  final String reference;
  final String name;
  final String email;
  final String subject;
  final String message;
  final EnquiryStatus status;
  final List<EnquiryReply> replies;
  final String phone;
  final String organisation;
  final DateTime? createdAt;

  /// Whether the sender was signed in, and so can be answered in the
  /// application as well as by email.
  final bool hasAccount;

  bool get awaitingReply =>
      status == EnquiryStatus.isNew || status == EnquiryStatus.read;

  factory Enquiry.fromMap(Map<String, dynamic> map) => Enquiry(
    id: _text(map, 'id'),
    reference: _text(map, 'reference'),
    name: _text(map, 'name'),
    email: _text(map, 'email'),
    subject: _text(map, 'subject'),
    message: _text(map, 'message'),
    status: EnquiryStatus.parse(_text(map, 'status')),
    phone: _text(map, 'phone'),
    organisation: _text(map, 'organisation'),
    createdAt: DateTime.tryParse(_text(map, 'created_at')),
    hasAccount: _text(map, 'user_id').isNotEmpty,
    replies: [
      for (final reply in (map['replies'] as List? ?? const []))
        EnquiryReply.fromMap(Map<String, dynamic>.from(reply as Map)),
    ],
  );
}

/// What the public form collects.
class EnquiryDraft {
  const EnquiryDraft({
    required this.name,
    required this.email,
    required this.message,
    this.phone = '',
    this.organisation = '',
    this.subject = '',
  });

  final String name;
  final String email;
  final String message;
  final String phone;
  final String organisation;
  final String subject;

  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'message': message,
    'phone': phone,
    'organisation': organisation,
    'subject': subject,
  };
}
