import '../domain/contact_models.dart';

/// The public contact channel.
///
/// Sending is open to everyone. Reading a thread is not: the API scopes
/// [myEnquiries] to the signed-in account, so one sender can never see
/// another's correspondence.
abstract interface class ContactRepository {
  /// Submits an enquiry and returns its reference, e.g. `WEA-ENQ-00019`.
  Future<String> sendEnquiry(EnquiryDraft draft);

  /// The signed-in sender's own enquiries, with any academy replies.
  Future<List<Enquiry>> myEnquiries();

  /// Adds a follow-up to one of the sender's own enquiries.
  Future<void> followUp({required String enquiryId, required String body});
}

/// The office side of the same channel. Super Admin only; the API re-checks.
abstract interface class ContactAdminRepository {
  Future<List<Enquiry>> enquiries({EnquiryStatus? status});

  Future<void> reply({required String enquiryId, required String body});

  Future<void> setStatus({
    required String enquiryId,
    required EnquiryStatus status,
  });
}
