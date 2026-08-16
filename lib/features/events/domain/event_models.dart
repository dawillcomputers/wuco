/// Models for WEA events, paid registration and the participant's own view.
///
/// Nothing about a particular event lives here. An event is a row a Super
/// Admin created — its price, its questions, its materials and its sessions
/// all arrive from the API — so adding the next summit needs no release.
library;

import '../../catalogue/domain/catalogue_models.dart' show resolveMediaUrl;

String _text(Map<String, dynamic> map, String key) =>
    (map[key] as String?)?.trim() ?? '${map[key] ?? ''}'.trim();

bool _bool(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value == true || value == 1 || value == '1' || value == 'true';
}

double _double(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

int? _int(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

DateTime? _date(Map<String, dynamic> map, String key) {
  final raw = _text(map, key);
  if (raw.isEmpty) return null;
  // The API stores SQLite timestamps as "2026-09-25 09:00:00" and ISO strings
  // interchangeably; both have to parse.
  return DateTime.tryParse(raw.contains('T') ? raw : raw.replaceFirst(' ', 'T'));
}

List<Map<String, dynamic>> _rows(Object? value) => [
  for (final row in (value as List? ?? const []))
    Map<String, dynamic>.from(row as Map),
];

List<String> _stringList(Object? value) => [
  for (final item in (value as List? ?? const []))
    if ('$item'.trim().isNotEmpty) '$item'.trim(),
];

// ---------------------------------------------------------------------------
// Enumerations
// ---------------------------------------------------------------------------

enum EventFormat {
  online,
  physical,
  hybrid;

  static EventFormat parse(String value) => switch (value.toUpperCase()) {
    // WALK_IN is accepted as well, so the vocabulary can move later without
    // this becoming the thing that breaks.
    'PHYSICAL' || 'WALK_IN' => EventFormat.physical,
    'HYBRID' => EventFormat.hybrid,
    _ => EventFormat.online,
  };

  /// How the academy names it. Physical means in the room, as against
  /// attending online.
  String get label => switch (this) {
    EventFormat.online => 'Online',
    EventFormat.physical => 'Physical',
    EventFormat.hybrid => 'Hybrid',
  };

  /// Whether attending involves a live room rather than only a venue.
  bool get hasLiveRoom => this != EventFormat.physical;
}

enum EventStatus {
  draft,
  published,
  registrationClosed,
  completed,
  cancelled,
  archived;

  static EventStatus parse(String value) => switch (value.toUpperCase()) {
    'PUBLISHED' => EventStatus.published,
    'REGISTRATION_CLOSED' => EventStatus.registrationClosed,
    'COMPLETED' => EventStatus.completed,
    'CANCELLED' => EventStatus.cancelled,
    'ARCHIVED' => EventStatus.archived,
    _ => EventStatus.draft,
  };

  String get label => switch (this) {
    EventStatus.draft => 'Draft',
    EventStatus.published => 'Open for registration',
    EventStatus.registrationClosed => 'Registration closed',
    EventStatus.completed => 'Completed',
    EventStatus.cancelled => 'Cancelled',
    EventStatus.archived => 'Archived',
  };
}

/// How far a registrant has travelled through the process.
enum EventRegistrationStatus {
  started,
  formCompleted,
  paymentPending,
  paymentProcessing,
  paid,
  paymentFailed,
  abandoned,
  cancelled,
  completed;

  static EventRegistrationStatus parse(String value) =>
      switch (value.toUpperCase()) {
        'FORM_COMPLETED' => EventRegistrationStatus.formCompleted,
        'PAYMENT_PENDING' => EventRegistrationStatus.paymentPending,
        'PAYMENT_PROCESSING' => EventRegistrationStatus.paymentProcessing,
        'PAID' => EventRegistrationStatus.paid,
        'PAYMENT_FAILED' => EventRegistrationStatus.paymentFailed,
        'ABANDONED' => EventRegistrationStatus.abandoned,
        'CANCELLED' => EventRegistrationStatus.cancelled,
        'COMPLETED' => EventRegistrationStatus.completed,
        _ => EventRegistrationStatus.started,
      };

  String get wireName => switch (this) {
    EventRegistrationStatus.started => 'STARTED',
    EventRegistrationStatus.formCompleted => 'FORM_COMPLETED',
    EventRegistrationStatus.paymentPending => 'PAYMENT_PENDING',
    EventRegistrationStatus.paymentProcessing => 'PAYMENT_PROCESSING',
    EventRegistrationStatus.paid => 'PAID',
    EventRegistrationStatus.paymentFailed => 'PAYMENT_FAILED',
    EventRegistrationStatus.abandoned => 'ABANDONED',
    EventRegistrationStatus.cancelled => 'CANCELLED',
    EventRegistrationStatus.completed => 'COMPLETED',
  };

  String get label => switch (this) {
    EventRegistrationStatus.started => 'Started',
    EventRegistrationStatus.formCompleted => 'Information completed',
    EventRegistrationStatus.paymentPending => 'Payment pending',
    EventRegistrationStatus.paymentProcessing => 'Payment processing',
    EventRegistrationStatus.paid => 'Paid',
    EventRegistrationStatus.paymentFailed => 'Payment failed',
    EventRegistrationStatus.abandoned => 'Abandoned',
    EventRegistrationStatus.cancelled => 'Cancelled',
    EventRegistrationStatus.completed => 'Confirmed',
  };
}

enum EventPaymentStatus {
  notRequired,
  pending,
  processing,
  paid,
  failed,
  refunded;

  static EventPaymentStatus parse(String value) => switch (value.toUpperCase()) {
    'PENDING' => EventPaymentStatus.pending,
    'PROCESSING' => EventPaymentStatus.processing,
    'PAID' => EventPaymentStatus.paid,
    'FAILED' => EventPaymentStatus.failed,
    'REFUNDED' => EventPaymentStatus.refunded,
    _ => EventPaymentStatus.notRequired,
  };

  String get label => switch (this) {
    EventPaymentStatus.notRequired => 'No payment required',
    EventPaymentStatus.pending => 'Awaiting payment',
    EventPaymentStatus.processing => 'Payment in progress',
    EventPaymentStatus.paid => 'Paid',
    EventPaymentStatus.failed => 'Payment failed',
    EventPaymentStatus.refunded => 'Refunded',
  };

  bool get settled =>
      this == EventPaymentStatus.paid || this == EventPaymentStatus.notRequired;
}

// ---------------------------------------------------------------------------
// The event
// ---------------------------------------------------------------------------

/// One line of a published agenda.
class EventAgendaItem {
  const EventAgendaItem({required this.time, required this.title, required this.detail});

  final String time;
  final String title;
  final String detail;

  factory EventAgendaItem.fromMap(Map<String, dynamic> map) => EventAgendaItem(
    time: _text(map, 'time'),
    title: _text(map, 'title'),
    detail: _text(map, 'detail'),
  );

  /// Also accepts a plain string, so an agenda can be typed as simple lines.
  factory EventAgendaItem.fromAny(Object? value) => value is Map
      ? EventAgendaItem.fromMap(Map<String, dynamic>.from(value))
      : EventAgendaItem(time: '', title: '$value', detail: '');
}

/// An event as it appears in a listing.
class WeaEvent {
  const WeaEvent({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.eventType,
    this.theme = '',
    required this.summary,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.venue,
    required this.format,
    required this.feeAmount,
    required this.feeCurrency,
    required this.status,
    required this.featured,
    required this.capacity,
    this.imageKey,
    this.imageUrl,
  });

  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final String eventType;

  /// The line the event is convened around, shown beneath the title.
  final String theme;
  final String summary;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String timezone;
  final String venue;
  final EventFormat format;
  final double feeAmount;
  final String feeCurrency;
  final EventStatus status;
  final bool featured;
  final int? capacity;
  final String? imageKey;
  final String? imageUrl;

  bool get isPaid => feeAmount > 0;

  String? get artwork => resolveMediaUrl(imageKey: imageKey, imageUrl: imageUrl);

  /// The fee as the academy quotes it — never computed from anything the
  /// visitor can change.
  String get feeLabel => isPaid ? formatMoney(feeAmount, feeCurrency) : 'Free to attend';

  factory WeaEvent.fromMap(Map<String, dynamic> map) => WeaEvent(
    id: _text(map, 'id'),
    slug: _text(map, 'slug'),
    title: _text(map, 'title'),
    subtitle: _text(map, 'subtitle'),
    eventType: _text(map, 'event_type'),
    theme: _text(map, 'theme'),
    summary: _text(map, 'summary'),
    startsAt: _date(map, 'starts_at'),
    endsAt: _date(map, 'ends_at'),
    timezone: _text(map, 'timezone'),
    venue: _text(map, 'venue'),
    format: EventFormat.parse(_text(map, 'format')),
    feeAmount: _double(map, 'fee_amount'),
    feeCurrency: _text(map, 'fee_currency'),
    status: EventStatus.parse(_text(map, 'status')),
    featured: _bool(map, 'featured'),
    capacity: _int(map, 'capacity'),
    imageKey: map['image_key'] as String?,
    imageUrl: map['image_url'] as String?,
  );
}

/// Everything the public event page shows.
class EventDetail {
  const EventDetail({
    required this.event,
    required this.description,
    required this.whyAttend,
    required this.whoShouldAttend,
    required this.agenda,
    required this.materials,
    required this.sessions,
    required this.contactEmail,
    required this.contactPhone,
    required this.terms,
    required this.paymentInstructions,
    required this.confirmedRegistrations,
    required this.placesRemaining,
    required this.registrationOpen,
    required this.allowGuestRegistration,
    required this.registrationClosesAt,
    this.highlights = const [],
    this.speakers = const [],
    this.whatIsIncluded = '',
    this.arrivalInformation = '',
    this.dressCode = '',
    this.accreditation = '',
    this.cancellationPolicy = '',
    this.registrationNote = '',
    this.flierUrl,
  });

  final WeaEvent event;
  final String description;
  final String whyAttend;
  final String whoShouldAttend;
  final List<EventAgendaItem> agenda;
  final List<EventMaterial> materials;
  final List<EventSession> sessions;
  final String contactEmail;
  final String contactPhone;
  final String terms;
  final String paymentInstructions;
  final int confirmedRegistrations;

  /// Null when the event has no capacity limit.
  final int? placesRemaining;
  final bool registrationOpen;
  final bool allowGuestRegistration;
  final DateTime? registrationClosesAt;

  /// The short reasons somebody should attend.
  final List<String> highlights;
  final List<String> speakers;
  final String whatIsIncluded;
  final String arrivalInformation;
  final String dressCode;
  final String accreditation;
  final String cancellationPolicy;

  /// Shown on the registration form, where it is actually read.
  final String registrationNote;

  /// A downloadable flier, separate from the page's banner artwork.
  final String? flierUrl;

  bool get hasFlier => (flierUrl ?? '').trim().isNotEmpty;

  /// Practicalities, rendered as one block so empty ones simply do not appear.
  List<(String, String)> get practicalities => [
    if (whatIsIncluded.isNotEmpty) ('What your fee includes', whatIsIncluded),
    if (arrivalInformation.isNotEmpty) ('Arrival and access', arrivalInformation),
    if (dressCode.isNotEmpty) ('Dress code', dressCode),
    if (accreditation.isNotEmpty) ('Accreditation', accreditation),
    if (cancellationPolicy.isNotEmpty)
      ('Cancellation and refunds', cancellationPolicy),
  ];

  factory EventDetail.fromMap(Map<String, dynamic> map) {
    final event = Map<String, dynamic>.from(map['event'] as Map? ?? const {});
    return EventDetail(
      event: WeaEvent.fromMap(event),
      description: _text(event, 'description'),
      whyAttend: _text(event, 'why_attend'),
      whoShouldAttend: _text(event, 'who_should_attend'),
      agenda: [
        for (final item in (event['agenda'] as List? ?? const []))
          EventAgendaItem.fromAny(item),
      ],
      materials: _rows(map['materials']).map(EventMaterial.fromMap).toList(),
      sessions: _rows(map['sessions']).map(EventSession.fromMap).toList(),
      contactEmail: _text(event, 'contact_email'),
      contactPhone: _text(event, 'contact_phone'),
      terms: _text(event, 'terms'),
      paymentInstructions: _text(event, 'payment_instructions'),
      confirmedRegistrations: _int(map, 'confirmed_registrations') ?? 0,
      placesRemaining: _int(map, 'places_remaining'),
      registrationOpen: _bool(map, 'registration_open'),
      allowGuestRegistration: _bool(event, 'allow_guest_registration'),
      registrationClosesAt: _date(event, 'registration_closes_at'),
      highlights: _stringList(event['highlights']),
      speakers: _stringList(event['speakers']),
      whatIsIncluded: _text(event, 'what_is_included'),
      arrivalInformation: _text(event, 'arrival_information'),
      dressCode: _text(event, 'dress_code'),
      accreditation: _text(event, 'accreditation'),
      cancellationPolicy: _text(event, 'cancellation_policy'),
      registrationNote: _text(event, 'registration_note'),
      flierUrl: resolveMediaUrl(
        imageKey: event['flier_key'] as String?,
        imageUrl: event['flier_url'] as String?,
      ),
    );
  }
}

class EventMaterial {
  const EventMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.materialType,
    required this.participantsOnly,
    this.mediaKey,
    this.resourceUrl,
  });

  final String id;
  final String title;
  final String description;
  final String materialType;
  final bool participantsOnly;
  final String? mediaKey;
  final String? resourceUrl;

  String? get url => resolveMediaUrl(imageKey: mediaKey, imageUrl: resourceUrl);

  factory EventMaterial.fromMap(Map<String, dynamic> map) => EventMaterial(
    id: _text(map, 'id'),
    title: _text(map, 'title'),
    description: _text(map, 'description'),
    materialType: _text(map, 'material_type'),
    participantsOnly: _text(map, 'visibility') == 'PARTICIPANT',
    mediaKey: map['media_key'] as String?,
    resourceUrl: map['resource_url'] as String?,
  );
}

/// A live sitting of an event.
///
/// The join link is deliberately absent: it is issued one request at a time by
/// the API once it has re-checked registration, payment and whether the host
/// has opened the room.
class EventSession {
  const EventSession({
    required this.id,
    required this.title,
    required this.sessionType,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.speaker,
    required this.notes,
    required this.isLive,
    this.recordingUrl,
  });

  final String id;
  final String title;
  final String sessionType;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String timezone;
  final String speaker;
  final String notes;
  final bool isLive;
  final String? recordingUrl;

  bool get hasRecording => (recordingUrl ?? '').trim().isNotEmpty;

  factory EventSession.fromMap(Map<String, dynamic> map) => EventSession(
    id: _text(map, 'id'),
    title: _text(map, 'title'),
    sessionType: _text(map, 'session_type'),
    startsAt: _date(map, 'starts_at'),
    endsAt: _date(map, 'ends_at'),
    timezone: _text(map, 'timezone'),
    speaker: _text(map, 'speaker'),
    notes: _text(map, 'notes'),
    isLive: _bool(map, 'is_live'),
    recordingUrl: map['recording_url'] as String?,
  );
}

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------

enum EventFieldType {
  text,
  textarea,
  select,
  checkbox,
  date,
  number;

  static EventFieldType parse(String value) => switch (value.toUpperCase()) {
    'TEXTAREA' => EventFieldType.textarea,
    'SELECT' => EventFieldType.select,
    'CHECKBOX' => EventFieldType.checkbox,
    'DATE' => EventFieldType.date,
    'NUMBER' => EventFieldType.number,
    _ => EventFieldType.text,
  };
}

/// A question an event asks. Configured by a Super Admin, never in code.
class EventRegistrationField {
  const EventRegistrationField({
    required this.id,
    required this.fieldKey,
    required this.label,
    required this.type,
    required this.options,
    required this.helpText,
    required this.required,
    required this.askEarly,
    this.prefill,
  });

  final String id;
  final String fieldKey;
  final String label;
  final EventFieldType type;
  final List<String> options;
  final String helpText;
  final bool required;

  /// Asked on the first step rather than after the essentials.
  final bool askEarly;

  /// What this person answered last time, where they have registered before.
  final String? prefill;

  factory EventRegistrationField.fromMap(Map<String, dynamic> map) =>
      EventRegistrationField(
        id: _text(map, 'id'),
        fieldKey: _text(map, 'field_key'),
        label: _text(map, 'label'),
        type: EventFieldType.parse(_text(map, 'field_type')),
        options: [
          for (final option in (map['options'] as List? ?? const [])) '$option',
        ],
        helpText: _text(map, 'help_text'),
        required: _bool(map, 'required'),
        askEarly: _bool(map, 'ask_early'),
        prefill: map['prefill'] == null ? null : '${map['prefill']}'.trim(),
      );
}

/// What the form should ask this person for this event.
class EventRegistrationContext {
  const EventRegistrationContext({
    required this.event,
    required this.known,
    required this.fields,
    required this.registrationOpen,
    required this.closedReason,
    this.existingRegistration,
    this.registrationNote = '',
  });

  final WeaEvent event;

  /// The academy's own note, shown at the moment somebody is deciding.
  final String registrationNote;

  /// What WEA already holds. Shown as confirmed, not asked for again.
  final Map<String, String> known;
  final List<EventRegistrationField> fields;
  final bool registrationOpen;
  final String? closedReason;

  /// Present when this person has already begun registering for this event,
  /// so the form resumes rather than starting a second attempt.
  final EventRegistration? existingRegistration;

  bool get isReturning => (known['email'] ?? '').isNotEmpty;

  String get firstName => known['first_name'] ?? '';

  factory EventRegistrationContext.fromMap(Map<String, dynamic> map) {
    final existing = map['existing_registration'];
    return EventRegistrationContext(
      event: WeaEvent.fromMap(
        Map<String, dynamic>.from(map['event'] as Map? ?? const {}),
      ),
      known: {
        for (final entry in (map['known'] as Map? ?? const {}).entries)
          '${entry.key}': '${entry.value ?? ''}',
      },
      fields: _rows(map['fields']).map(EventRegistrationField.fromMap).toList(),
      registrationOpen: _bool(map, 'registration_open'),
      closedReason: map['closed_reason'] as String?,
      registrationNote: _text(
        Map<String, dynamic>.from(map['event'] as Map? ?? const {}),
        'registration_note',
      ),
      existingRegistration: existing == null
          ? null
          : EventRegistration.fromMap(Map<String, dynamic>.from(existing as Map)),
    );
  }
}

/// What the registrant has told WEA, and where the registration has got to.
class EventRegistration {
  const EventRegistration({
    required this.id,
    required this.reference,
    required this.eventId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.organisation,
    required this.jobTitle,
    required this.country,
    required this.answers,
    required this.status,
    required this.paymentStatus,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String reference;
  final String eventId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String organisation;
  final String jobTitle;
  final String country;
  final Map<String, String> answers;
  final EventRegistrationStatus status;
  final EventPaymentStatus paymentStatus;
  final double amount;
  final String currency;
  final DateTime? createdAt;
  final DateTime? completedAt;

  String get fullName => '$firstName $lastName'.trim();

  bool get requiresPayment => amount > 0;

  /// A confirmed place: paid where payment was due, or a free event finished.
  bool get isConfirmed =>
      paymentStatus.settled && status == EventRegistrationStatus.completed;

  String get amountLabel => formatMoney(amount, currency);

  factory EventRegistration.fromMap(Map<String, dynamic> map) => EventRegistration(
    id: _text(map, 'id'),
    reference: _text(map, 'reference'),
    eventId: _text(map, 'event_id'),
    firstName: _text(map, 'first_name'),
    lastName: _text(map, 'last_name'),
    email: _text(map, 'email'),
    phone: _text(map, 'phone'),
    organisation: _text(map, 'organisation'),
    jobTitle: _text(map, 'job_title'),
    country: _text(map, 'country'),
    answers: {
      for (final entry in (map['answers'] as Map? ?? const {}).entries)
        '${entry.key}': '${entry.value ?? ''}',
    },
    status: EventRegistrationStatus.parse(_text(map, 'status')),
    paymentStatus: EventPaymentStatus.parse(_text(map, 'payment_status')),
    amount: _double(map, 'amount'),
    currency: _text(map, 'currency'),
    createdAt: _date(map, 'created_at'),
    completedAt: _date(map, 'completed_at'),
  );
}

/// A registration alongside the event it is for, as listed on "my events".
class MyEventRegistration {
  const MyEventRegistration({required this.registration, required this.event});

  final EventRegistration registration;
  final WeaEvent event;

  factory MyEventRegistration.fromMap(Map<String, dynamic> map) =>
      MyEventRegistration(
        registration: EventRegistration.fromMap(map),
        event: WeaEvent.fromMap({
          'id': map['event_id'],
          'slug': map['event_slug'],
          'title': map['event_title'],
          'starts_at': map['event_starts_at'],
          'venue': map['event_venue'],
          'format': map['event_format'],
          'image_key': map['event_image_key'],
          'fee_amount': map['amount'],
          'fee_currency': map['currency'],
        }),
      );
}

/// A way to pay that this event can actually take.
///
/// Reported by the API, never assembled by the client: whether a method works
/// depends on the academy's configuration and the processor's account, and
/// neither is knowable here.
class EventPaymentMethod {
  const EventPaymentMethod({
    required this.key,
    required this.label,
    required this.description,
    required this.flow,
  });

  final String key;
  final String label;
  final String description;

  /// `redirect` sends the payer to the processor; `directCharge` returns
  /// instructions to follow, such as an account to transfer to.
  final String flow;

  bool get isRedirect => flow == 'redirect';

  factory EventPaymentMethod.fromMap(Map<String, dynamic> map) =>
      EventPaymentMethod(
        key: _text(map, 'key'),
        label: _text(map, 'label'),
        description: _text(map, 'description'),
        flow: _text(map, 'flow'),
      );
}

/// One price the academy has set. WEA never converts between them.
class EventPrice {
  const EventPrice({required this.currency, required this.amount});

  final String currency;
  final double amount;

  String get label => formatMoney(amount, currency);

  factory EventPrice.fromMap(Map<String, dynamic> map) => EventPrice(
    currency: _text(map, 'currency'),
    amount: _double(map, 'amount'),
  );
}

/// How a registrant is attending. Only ever a choice on a hybrid event.
enum EventAttendanceMode {
  physical,
  virtual;

  static EventAttendanceMode? parse(String value) => switch (value.toUpperCase()) {
    'PHYSICAL' => EventAttendanceMode.physical,
    'VIRTUAL' => EventAttendanceMode.virtual,
    _ => null,
  };

  String get wire => name.toUpperCase();

  String get label => switch (this) {
    EventAttendanceMode.physical => 'Attend in person',
    EventAttendanceMode.virtual => 'Attend online',
  };

  String get shortLabel => switch (this) {
    EventAttendanceMode.physical => 'In person',
    EventAttendanceMode.virtual => 'Online',
  };
}

/// One rate on an event's fee table.
///
/// The registrant never picks one of these. Which applies follows from the
/// date and from how they are attending, and the server decides it.
class EventFeeTier {
  const EventFeeTier({
    required this.label,
    required this.prices,
    this.attendanceMode = 'ANY',
    this.availableUntil,
    this.open = true,
  });

  final String label;
  final List<EventPrice> prices;
  final String attendanceMode;

  /// When this rate closes. Null for the rate that applies afterwards.
  final DateTime? availableUntil;

  /// Whether it applies today. A closed rate is still shown, greyed, so a
  /// registrant can see what they missed and what the current rate replaced.
  final bool open;

  EventAttendanceMode? get mode => EventAttendanceMode.parse(attendanceMode);

  EventPrice? priceIn(String currency) {
    for (final price in prices) {
      if (price.currency == currency) return price;
    }
    return prices.isEmpty ? null : prices.first;
  }

  factory EventFeeTier.fromMap(Map<String, dynamic> map) => EventFeeTier(
    label: _text(map, 'label'),
    prices: _rows(map['prices']).map(EventPrice.fromMap).toList(),
    attendanceMode: _text(map, 'attendance_mode'),
    availableUntil: _date(map, 'available_until'),
    open: map['open'] != false,
  );
}

/// The methods offered for one event, and which environment they run in.
class EventPaymentOptions {
  const EventPaymentOptions({
    required this.methods,
    required this.environment,
    this.prices = const [],
    this.currency = '',
    this.suggestedCurrency = '',
    this.tierLabel = '',
    this.tierClosesAt,
    this.attendanceMode = '',
    this.attendanceModes = const [],
    this.feeTiers = const [],
  });

  final List<EventPaymentMethod> methods;

  /// The rate being charged, e.g. `Early Bird`. Empty when the event has a
  /// single unnamed fee.
  final String tierLabel;

  /// When that rate closes, so the registrant can be told rather than simply
  /// charged more one morning.
  final DateTime? tierClosesAt;

  /// The way of attending these prices are for.
  final String attendanceMode;

  /// The ways of attending that have a price. Empty on an event with only one
  /// — there is nothing to ask.
  final List<EventAttendanceMode> attendanceModes;

  /// The whole fee table, so a registrant can see both ways of attending and
  /// what the rate becomes later.
  final List<EventFeeTier> feeTiers;

  /// Every currency the academy priced this in. A currency absent here is one
  /// WEA does not sell in, rather than one to convert into.
  final List<EventPrice> prices;

  /// The currency these methods and this price apply to.
  final String currency;

  /// What the payer's location suggests — naira in Nigeria, dollars outside.
  final String suggestedCurrency;

  bool get hasChoice => prices.length > 1;

  /// Whether there is a way of attending to choose between.
  bool get hasModeChoice => attendanceModes.length > 1;

  EventAttendanceMode? get mode => EventAttendanceMode.parse(attendanceMode);

  EventPrice? get price {
    for (final option in prices) {
      if (option.currency == currency) return option;
    }
    return prices.isEmpty ? null : prices.first;
  }

  /// The rate for a way of attending, so the picker can show both prices
  /// rather than making the registrant switch to find out.
  EventFeeTier? tierFor(EventAttendanceMode wanted) {
    for (final tier in feeTiers) {
      if (!tier.open) continue;
      if (tier.mode == wanted || tier.attendanceMode == 'ANY') return tier;
    }
    return null;
  }

  /// What the rate becomes once the current one closes, if anything does.
  EventFeeTier? get nextTier {
    if (tierClosesAt == null) return null;
    for (final tier in feeTiers) {
      final matches =
          tier.mode == mode || tier.attendanceMode == 'ANY' || mode == null;
      if (matches && tier.availableUntil == null && tier.label != tierLabel) {
        return tier;
      }
    }
    return null;
  }

  /// `SANDBOX` or `PRODUCTION`. Shown so a test payment is never mistaken
  /// for a real one.
  final String environment;

  bool get isSandbox => environment.toUpperCase() == 'SANDBOX';

  factory EventPaymentOptions.fromMap(Map<String, dynamic> map) {
    final tier = map['tier'];
    final tierMap = tier is Map<String, dynamic> ? tier : const <String, dynamic>{};
    return EventPaymentOptions(
      methods: _rows(map['methods']).map(EventPaymentMethod.fromMap).toList(),
      environment: _text(map, 'environment'),
      prices: _rows(map['prices']).map(EventPrice.fromMap).toList(),
      currency: _text(map, 'currency'),
      suggestedCurrency: _text(map, 'suggested_currency'),
      tierLabel: _text(tierMap, 'label'),
      tierClosesAt: _date(tierMap, 'available_until'),
      attendanceMode: _text(map, 'attendance_mode'),
      attendanceModes: [
        for (final value in (map['attendance_modes'] as List? ?? const []))
          ?EventAttendanceMode.parse('$value'),
      ],
      feeTiers: _rows(map['fee_tiers']).map(EventFeeTier.fromMap).toList(),
    );
  }
}

/// What the API says to do next in order to pay.
///
/// Either there is a checkout to send the payer to, or there are instructions
/// from the academy — the client does not need to know which processor, or
/// whether there is one at all.
class EventPaymentIntent {
  const EventPaymentIntent({
    required this.provider,
    required this.paymentReference,
    required this.amount,
    required this.currency,
    required this.instructions,
    this.checkoutUrl,
  });

  final String provider;
  final String paymentReference;
  final double amount;
  final String currency;
  final String instructions;
  final String? checkoutUrl;

  bool get hasCheckout => (checkoutUrl ?? '').trim().isNotEmpty;

  factory EventPaymentIntent.fromMap(Map<String, dynamic> map) => EventPaymentIntent(
    provider: _text(map, 'provider'),
    paymentReference: _text(map, 'payment_reference'),
    amount: _double(map, 'amount'),
    currency: _text(map, 'currency'),
    instructions: _text(map, 'instructions'),
    checkoutUrl: map['checkout_url'] as String?,
  );
}

/// The result of asking the API to confirm a payment with the processor.
class EventPaymentOutcome {
  const EventPaymentOutcome({
    required this.status,
    required this.registrationStatus,
    required this.paymentStatus,
    required this.reason,
  });

  final String status;
  final EventRegistrationStatus registrationStatus;
  final EventPaymentStatus paymentStatus;
  final String reason;

  bool get succeeded => paymentStatus == EventPaymentStatus.paid;

  /// Still with the processor. Worth asking again in a moment.
  bool get pending =>
      paymentStatus == EventPaymentStatus.processing ||
      paymentStatus == EventPaymentStatus.pending;

  factory EventPaymentOutcome.fromMap(Map<String, dynamic> map) =>
      EventPaymentOutcome(
        status: _text(map, 'status'),
        registrationStatus: EventRegistrationStatus.parse(
          _text(map, 'registration_status'),
        ),
        paymentStatus: EventPaymentStatus.parse(_text(map, 'payment_status')),
        reason: _text(map, 'reason'),
      );
}

/// The participant's dashboard for one event.
class EventDashboard {
  const EventDashboard({
    required this.event,
    required this.registration,
    required this.materials,
    required this.sessions,
    required this.entitled,
    required this.agenda,
    required this.successMessage,
  });

  final WeaEvent event;
  final EventRegistration registration;
  final List<EventMaterial> materials;
  final List<EventSession> sessions;

  /// Whether the registration entitles this person to participant material and
  /// live sessions. Decided by the API; the interface only reflects it.
  final bool entitled;
  final List<EventAgendaItem> agenda;
  final String successMessage;

  EventSession? get liveNow {
    for (final session in sessions) {
      if (session.isLive) return session;
    }
    return null;
  }

  factory EventDashboard.fromMap(Map<String, dynamic> map) {
    final event = Map<String, dynamic>.from(map['event'] as Map? ?? const {});
    return EventDashboard(
      event: WeaEvent.fromMap(event),
      registration: EventRegistration.fromMap(
        Map<String, dynamic>.from(map['registration'] as Map? ?? const {}),
      ),
      materials: _rows(map['materials']).map(EventMaterial.fromMap).toList(),
      sessions: _rows(map['sessions']).map(EventSession.fromMap).toList(),
      entitled: _bool(map, 'entitled'),
      agenda: [
        for (final item in (event['agenda'] as List? ?? const []))
          EventAgendaItem.fromAny(item),
      ],
      successMessage: _text(event, 'success_message'),
    );
  }
}

// ---------------------------------------------------------------------------
// Administration
// ---------------------------------------------------------------------------

/// One registrant as the academy sees them, including the ones who never
/// finished. That is the point: an abandoned attempt is still a person who
/// asked to come.
class EventRegistrant {
  const EventRegistrant({
    required this.id,
    required this.reference,
    required this.eventTitle,
    required this.name,
    required this.email,
    required this.phone,
    required this.organisation,
    required this.jobTitle,
    required this.country,
    required this.status,
    required this.paymentStatus,
    required this.amount,
    required this.currency,
    required this.campaign,
    required this.createdAt,
    required this.lastActivityAt,
    required this.adminNote,
  });

  final String id;
  final String reference;
  final String eventTitle;
  final String name;
  final String email;
  final String phone;
  final String organisation;
  final String jobTitle;
  final String country;
  final EventRegistrationStatus status;
  final EventPaymentStatus paymentStatus;
  final double amount;
  final String currency;
  final String campaign;
  final DateTime? createdAt;
  final DateTime? lastActivityAt;
  final String adminNote;

  /// Someone who gave their details and did not complete. A lead, not a loss.
  bool get isLead => !paymentStatus.settled;

  factory EventRegistrant.fromMap(Map<String, dynamic> map) => EventRegistrant(
    id: _text(map, 'id'),
    reference: _text(map, 'reference'),
    eventTitle: _text(map, 'event_title'),
    name: '${_text(map, 'first_name')} ${_text(map, 'last_name')}'.trim(),
    email: _text(map, 'email'),
    phone: _text(map, 'phone'),
    organisation: _text(map, 'organisation'),
    jobTitle: _text(map, 'job_title'),
    country: _text(map, 'country'),
    status: EventRegistrationStatus.parse(_text(map, 'status')),
    paymentStatus: EventPaymentStatus.parse(_text(map, 'payment_status')),
    amount: _double(map, 'amount'),
    currency: _text(map, 'currency'),
    campaign: _text(map, 'utm_campaign'),
    createdAt: _date(map, 'created_at'),
    lastActivityAt: _date(map, 'last_activity_at'),
    adminNote: _text(map, 'admin_note'),
  );
}

/// Headline numbers for an event. Revenue counts verified payments only.
class EventOverview {
  const EventOverview({
    required this.totalAttempts,
    required this.completed,
    required this.paymentPending,
    required this.paymentProcessing,
    required this.paymentFailed,
    required this.abandoned,
    required this.started,
    required this.revenue,
  });

  final int totalAttempts;
  final int completed;
  final int paymentPending;
  final int paymentProcessing;
  final int paymentFailed;
  final int abandoned;
  final int started;

  /// Verified revenue per currency. Pending and abandoned are never in here.
  final Map<String, double> revenue;

  factory EventOverview.fromMap(Map<String, dynamic> map) => EventOverview(
    totalAttempts: _int(map, 'total_attempts') ?? 0,
    completed: _int(map, 'completed') ?? 0,
    paymentPending: _int(map, 'payment_pending') ?? 0,
    paymentProcessing: _int(map, 'payment_processing') ?? 0,
    paymentFailed: _int(map, 'payment_failed') ?? 0,
    abandoned: _int(map, 'abandoned') ?? 0,
    started: _int(map, 'started') ?? 0,
    revenue: {
      for (final row in _rows(map['revenue']))
        _text(row, 'currency'): _double(row, 'total'),
    },
  );
}

/// The registration funnel, from landing page to confirmed place.
class EventFunnel {
  const EventFunnel({
    required this.landingPageViews,
    required this.landingPageVisitors,
    required this.startedRegistration,
    required this.completedForm,
    required this.paymentAttempts,
    required this.successfulPayments,
    required this.failedPayments,
    required this.abandoned,
    required this.completedRegistrations,
    required this.conversionRate,
  });

  final int landingPageViews;
  final int landingPageVisitors;
  final int startedRegistration;
  final int completedForm;
  final int paymentAttempts;
  final int successfulPayments;
  final int failedPayments;
  final int abandoned;
  final int completedRegistrations;

  /// Null rather than zero when there is nothing yet to compute it from.
  final double? conversionRate;

  factory EventFunnel.fromMap(Map<String, dynamic> map) => EventFunnel(
    landingPageViews: _int(map, 'landing_page_views') ?? 0,
    landingPageVisitors: _int(map, 'landing_page_visitors') ?? 0,
    startedRegistration: _int(map, 'started_registration') ?? 0,
    completedForm: _int(map, 'completed_form') ?? 0,
    paymentAttempts: _int(map, 'payment_attempts') ?? 0,
    successfulPayments: _int(map, 'successful_payments') ?? 0,
    failedPayments: _int(map, 'failed_payments') ?? 0,
    abandoned: _int(map, 'abandoned') ?? 0,
    completedRegistrations: _int(map, 'completed_registrations') ?? 0,
    conversionRate: map['conversion_rate'] == null
        ? null
        : _double(map, 'conversion_rate'),
  );
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

const _currencySymbols = <String, String>{
  'NGN': '₦',
  'USD': r'$',
  'GBP': '£',
  'EUR': '€',
};

/// Money as the academy writes it: symbol where there is one, grouped digits,
/// and no decimals on whole amounts.
String formatMoney(double amount, String currency) {
  final code = currency.trim().toUpperCase();
  final symbol = _currencySymbols[code];
  final whole = amount.truncateToDouble() == amount;
  final digits = whole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  final parts = digits.split('.');
  final grouped = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );
  final rendered = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  return symbol == null ? '$code $rendered' : '$symbol$rendered';
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String formatEventDate(DateTime? date) {
  if (date == null) return 'Date to be announced';
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

String formatEventTime(DateTime? date) {
  if (date == null) return '';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// "25 September 2026 · 09:00–17:00 WAT", omitting whatever is not known.
String formatEventWhen(DateTime? start, DateTime? end, String timezone) {
  if (start == null) return 'Date to be announced';
  final buffer = StringBuffer(formatEventDate(start));
  final startTime = formatEventTime(start);
  if (startTime.isNotEmpty && startTime != '00:00') {
    buffer.write(' · $startTime');
    final endTime = formatEventTime(end);
    if (end != null && endTime.isNotEmpty && endTime != '00:00') {
      buffer.write('–$endTime');
    }
    if (timezone.trim().isNotEmpty) buffer.write(' $timezone');
  }
  return buffer.toString();
}
