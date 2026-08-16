import 'package:flutter/material.dart';

/// How one editable column is presented in the CMS.
enum CmsFieldKind {
  text,
  multiline,
  richText,
  number,
  currency,
  toggle,
  status,
  image,
  stringList,
  /// Prices in several currencies, edited as `USD 1500` lines and stored as
  /// `{"USD": 1500}`. WEA never converts, so each one is set deliberately.
  prices,
  /// A calendar date, stored as `YYYY-MM-DD`.
  date,
  /// A date and a time, stored as `YYYY-MM-DDTHH:MM:SS`.
  dateTime,
  select,
  /// A reference to another resource, chosen from a dropdown.
  reference,
}

class CmsField {
  const CmsField({
    required this.column,
    required this.label,
    this.kind = CmsFieldKind.text,
    this.help = '',
    this.required = false,
    this.options = const [],
    this.optionLabels = const {},
    this.referenceResource,
    this.referenceLabelColumn = 'title',
  });

  final String column;
  final String label;
  final CmsFieldKind kind;
  final String help;
  final bool required;
  final List<String> options;

  /// How a stored value should read in the dropdown, where the two differ.
  /// The database keeps `PHYSICAL`; an operator should see "Walk-in".
  final Map<String, String> optionLabels;

  /// The wording for one option, falling back to the value itself.
  String labelFor(String option) => optionLabels[option] ?? option;

  /// For [CmsFieldKind.reference]: the resource whose rows populate the list.
  final String? referenceResource;
  final String referenceLabelColumn;
}

/// A CMS-managed content type.
///
/// These mirror the Worker's resource specs. Keeping the description
/// declarative on both sides is what makes "add a programme without touching
/// code" true: the operator gets a real form, and adding a managed entity is a
/// descriptor on each side rather than a bespoke screen.
class CmsResource {
  const CmsResource({
    required this.name,
    required this.singular,
    required this.plural,
    required this.icon,
    required this.fields,
    this.titleColumn = 'title',
    this.subtitleColumn,
    this.hasStatus = true,
    this.filterBy,
    this.description = '',
  });

  /// Route segment used by the API: `/api/admin/<name>`.
  final String name;
  final String singular;
  final String plural;
  final IconData icon;
  final List<CmsField> fields;
  final String titleColumn;
  final String? subtitleColumn;
  final bool hasStatus;

  /// Column this resource is filtered by, with the parent resource it belongs
  /// to — modules belong to a programme, lessons to a module.
  final (String column, String parentResource)? filterBy;
  final String description;
}

const _statusField = CmsField(
  column: 'status',
  label: 'Status',
  kind: CmsFieldKind.status,
  help: 'Only published content appears on the public site.',
);

/// A status as an operator should read it.
String statusLabel(String status) => switch (status) {
  'PUBLISHED' => 'Published',
  'ARCHIVED' => 'Archived',
  'REGISTRATION_CLOSED' => 'Registration closed',
  'COMPLETED' => 'Completed',
  'CANCELLED' => 'Cancelled',
  _ => 'Draft',
};

/// Every content type a Super Admin can manage.
const cmsResources = <CmsResource>[
  CmsResource(
    name: 'areas',
    singular: 'Programme area',
    plural: 'Programme areas',
    icon: Icons.category_outlined,
    subtitleColumn: 'tagline',
    description:
        'Flagship areas shown on the public catalogue. Each one holds its own programmes.',
    fields: [
      CmsField(column: 'title', label: 'Title', required: true),
      CmsField(column: 'code', label: 'Code', help: 'Shown as 01, 02, 03…'),
      CmsField(column: 'tagline', label: 'Tagline'),
      CmsField(
        column: 'summary',
        label: 'Summary',
        kind: CmsFieldKind.multiline,
        help: 'One or two sentences, shown on the catalogue card.',
      ),
      CmsField(
        column: 'description',
        label: 'Full description',
        kind: CmsFieldKind.richText,
      ),
      CmsField(column: 'image_key', label: 'Image', kind: CmsFieldKind.image),
      _statusField,
    ],
  ),
  CmsResource(
    name: 'types',
    singular: 'Programme type',
    plural: 'Programme types',
    icon: Icons.style_outlined,
    subtitleColumn: 'description',
    description:
        'Formats such as Executive Certificate or Masterclass. Add a new type at any time.',
    fields: [
      CmsField(column: 'title', label: 'Title', required: true),
      CmsField(
        column: 'plural_title',
        label: 'Plural title',
        help: 'Used as a section heading, e.g. "Masterclasses".',
      ),
      CmsField(
        column: 'description',
        label: 'Description',
        kind: CmsFieldKind.multiline,
      ),
      _statusField,
    ],
  ),
  CmsResource(
    name: 'programmes',
    singular: 'Programme',
    plural: 'Programmes',
    icon: Icons.workspace_premium_outlined,
    subtitleColumn: 'summary',
    description:
        'Certificates, masterclasses, short courses and short cases. Publishing one puts it on the public site immediately.',
    fields: [
      CmsField(column: 'title', label: 'Title', required: true),
      CmsField(
        column: 'area_id',
        label: 'Programme area',
        kind: CmsFieldKind.reference,
        referenceResource: 'areas',
        required: true,
      ),
      CmsField(
        column: 'type_id',
        label: 'Programme type',
        kind: CmsFieldKind.reference,
        referenceResource: 'types',
        required: true,
      ),
      CmsField(column: 'subtitle', label: 'Subtitle'),
      CmsField(
        column: 'summary',
        label: 'Summary',
        kind: CmsFieldKind.multiline,
        help: 'Shown on catalogue cards and search results.',
      ),
      CmsField(
        column: 'description',
        label: 'Full description',
        kind: CmsFieldKind.richText,
      ),
      CmsField(column: 'image_key', label: 'Image', kind: CmsFieldKind.image),
      CmsField(
        column: 'learning_outcomes',
        label: 'What you will learn',
        kind: CmsFieldKind.stringList,
        help: 'One outcome per line.',
      ),
      CmsField(
        column: 'who_should_attend',
        label: 'Who should attend',
        kind: CmsFieldKind.multiline,
      ),
      CmsField(
        column: 'eligibility',
        label: 'Eligibility',
        kind: CmsFieldKind.multiline,
      ),
      CmsField(column: 'duration_label', label: 'Duration'),
      CmsField(
        column: 'delivery_mode',
        label: 'Delivery mode',
        kind: CmsFieldKind.select,
        options: ['Online', 'Blended', 'In person', 'Live online'],
      ),
      CmsField(
        column: 'level',
        label: 'Level',
        kind: CmsFieldKind.select,
        options: [
          'Professional',
          'Executive',
          'Advanced Executive',
          'Senior Executive',
        ],
      ),
      CmsField(column: 'language', label: 'Language'),
      CmsField(column: 'certificate_award', label: 'Certificate awarded'),
      CmsField(column: 'start_date', label: 'Start date', kind: CmsFieldKind.date),
      CmsField(
        column: 'application_deadline',
        label: 'Applications close',
        kind: CmsFieldKind.date,
      ),
      CmsField(
        column: 'tuition_amount',
        label: 'Tuition',
        kind: CmsFieldKind.currency,
      ),
      CmsField(column: 'tuition_currency', label: 'Currency'),
      CmsField(column: 'tuition_note', label: 'Tuition note'),
      CmsField(column: 'cpd_points', label: 'CPD points', kind: CmsFieldKind.number),
      CmsField(column: 'capacity', label: 'Capacity', kind: CmsFieldKind.number),
      CmsField(
        column: 'prices',
        label: 'Tuition in other currencies',
        kind: CmsFieldKind.prices,
        help:
            'One per line, e.g. "USD 1500". The tuition above is the base '
            'price. WEA never converts — a currency with no price set here is '
            'simply not offered, so set each one deliberately.',
      ),
      CmsField(
        column: 'registration_open',
        label: 'Registration open',
        kind: CmsFieldKind.toggle,
      ),
      CmsField(
        column: 'featured',
        label: 'Featured on the homepage',
        kind: CmsFieldKind.toggle,
      ),
      _statusField,
    ],
  ),
  CmsResource(
    name: 'modules',
    singular: 'Module',
    plural: 'Modules',
    icon: Icons.view_module_outlined,
    hasStatus: false,
    filterBy: ('programme_id', 'programmes'),
    subtitleColumn: 'summary',
    description: 'The structure shown on a programme page.',
    fields: [
      CmsField(
        column: 'programme_id',
        label: 'Programme',
        kind: CmsFieldKind.reference,
        referenceResource: 'programmes',
        required: true,
      ),
      CmsField(column: 'title', label: 'Title', required: true),
      CmsField(column: 'number', label: 'Number', kind: CmsFieldKind.number),
      CmsField(
        column: 'summary',
        label: 'Summary',
        kind: CmsFieldKind.multiline,
      ),
      CmsField(column: 'duration_label', label: 'Duration'),
    ],
  ),
  CmsResource(
    name: 'lessons',
    singular: 'Lesson',
    plural: 'Lessons',
    icon: Icons.play_lesson_outlined,
    hasStatus: false,
    filterBy: ('module_id', 'modules'),
    subtitleColumn: 'summary',
    description: 'Lesson content inside a module.',
    fields: [
      CmsField(
        column: 'module_id',
        label: 'Module',
        kind: CmsFieldKind.reference,
        referenceResource: 'modules',
        required: true,
      ),
      CmsField(column: 'title', label: 'Title', required: true),
      CmsField(column: 'number', label: 'Number', kind: CmsFieldKind.number),
      CmsField(
        column: 'lesson_type',
        label: 'Type',
        kind: CmsFieldKind.select,
        options: [
          'VIDEO',
          'TEXT',
          'PDF',
          'PRESENTATION',
          'AUDIO',
          'EXTERNAL',
          'QUIZ',
          'ASSIGNMENT',
          'CASE_STUDY',
          'LIVE_SESSION',
        ],
      ),
      CmsField(
        column: 'duration_minutes',
        label: 'Duration (minutes)',
        kind: CmsFieldKind.number,
      ),
      CmsField(column: 'summary', label: 'Summary', kind: CmsFieldKind.multiline),
      CmsField(column: 'body', label: 'Lesson content', kind: CmsFieldKind.richText),
      CmsField(column: 'resource_url', label: 'Resource link'),
      CmsField(column: 'media_key', label: 'Media', kind: CmsFieldKind.image),
      CmsField(
        column: 'is_preview',
        label: 'Free preview',
        kind: CmsFieldKind.toggle,
      ),
    ],
  ),
  CmsResource(
    name: 'faculty',
    singular: 'Faculty member',
    plural: 'Faculty',
    icon: Icons.person_outline,
    titleColumn: 'name',
    subtitleColumn: 'role_title',
    description: 'Faculty profiles shown on programme pages.',
    fields: [
      CmsField(column: 'name', label: 'Name', required: true),
      CmsField(column: 'role_title', label: 'Role'),
      CmsField(column: 'organisation', label: 'Organisation'),
      CmsField(column: 'bio', label: 'Biography', kind: CmsFieldKind.richText),
      CmsField(
        column: 'expertise',
        label: 'Areas of expertise',
        kind: CmsFieldKind.stringList,
        help: 'One per line.',
      ),
      CmsField(column: 'image_key', label: 'Photograph', kind: CmsFieldKind.image),
      CmsField(column: 'linkedin_url', label: 'LinkedIn'),
      _statusField,
    ],
  ),
  CmsResource(
    name: 'sessions',
    singular: 'Live session',
    plural: 'Live sessions',
    icon: Icons.event_outlined,
    filterBy: ('programme_id', 'programmes'),
    subtitleColumn: 'starts_at',
    description: 'Live classes, briefings and intakes shown on programme pages.',
    fields: [
      CmsField(
        column: 'programme_id',
        label: 'Programme',
        kind: CmsFieldKind.reference,
        referenceResource: 'programmes',
        required: true,
      ),
      CmsField(column: 'title', label: 'Title', required: true),
      CmsField(
        column: 'session_type',
        label: 'Type',
        kind: CmsFieldKind.select,
        options: ['LIVE_CLASS', 'MASTERCLASS', 'BRIEFING', 'INTAKE', 'EXAM'],
      ),
      CmsField(
        column: 'starts_at',
        label: 'Starts',
        kind: CmsFieldKind.dateTime,
      ),
      CmsField(
        column: 'ends_at',
        label: 'Ends',
        kind: CmsFieldKind.dateTime,
      ),
      CmsField(column: 'timezone', label: 'Timezone'),
      CmsField(column: 'mode', label: 'Mode'),
      CmsField(column: 'location', label: 'Location'),
      CmsField(column: 'join_url', label: 'Join link'),
      CmsField(
        column: 'faculty_id',
        label: 'Lecturer',
        kind: CmsFieldKind.reference,
        referenceResource: 'faculty',
        referenceLabelColumn: 'name',
      ),
      CmsField(column: 'notes', label: 'Notes', kind: CmsFieldKind.multiline),
      _statusField,
    ],
  ),
  CmsResource(
    name: 'registration-fields',
    singular: 'Registration question',
    plural: 'Registration questions',
    icon: Icons.help_outline,
    hasStatus: false,
    titleColumn: 'label',
    subtitleColumn: 'field_key',
    description:
        'Questions asked at registration. Leave the programme empty to ask it on every programme.',
    fields: [
      CmsField(column: 'label', label: 'Question', required: true),
      CmsField(
        column: 'field_key',
        label: 'Key',
        required: true,
        help: 'Stable identifier, e.g. job_title. Do not change it later.',
      ),
      CmsField(
        column: 'programme_id',
        label: 'Programme',
        kind: CmsFieldKind.reference,
        referenceResource: 'programmes',
        help: 'Leave empty to ask this on every programme.',
      ),
      CmsField(
        column: 'field_type',
        label: 'Answer type',
        kind: CmsFieldKind.select,
        options: ['TEXT', 'TEXTAREA', 'SELECT', 'CHECKBOX', 'DATE', 'NUMBER'],
      ),
      CmsField(
        column: 'options',
        label: 'Choices',
        kind: CmsFieldKind.stringList,
        help: 'One per line. Used when the answer type is SELECT.',
      ),
      CmsField(column: 'help_text', label: 'Help text'),
      CmsField(column: 'required', label: 'Required', kind: CmsFieldKind.toggle),
    ],
  ),
  CmsResource(
    name: 'payment-methods',
    singular: 'Payment method',
    plural: 'Payment methods',
    icon: Icons.payments_outlined,
    hasStatus: false,
    subtitleColumn: 'kind',
    description:
        'How applicants may pay. Bank details and gateway settings are configuration, never code.',
    fields: [
      CmsField(column: 'title', label: 'Title', required: true),
      CmsField(
        column: 'kind',
        label: 'Kind',
        kind: CmsFieldKind.select,
        options: ['BANK_TRANSFER', 'GATEWAY', 'INVOICE', 'OFFLINE'],
      ),
      CmsField(
        column: 'instructions',
        label: 'Instructions',
        kind: CmsFieldKind.richText,
      ),
      CmsField(column: 'bank_name', label: 'Bank name'),
      CmsField(column: 'account_name', label: 'Account name'),
      CmsField(column: 'account_number', label: 'Account number'),
      CmsField(column: 'sort_code', label: 'Sort code'),
      CmsField(column: 'swift_code', label: 'SWIFT / BIC'),
      CmsField(column: 'currency', label: 'Currency'),
      CmsField(
        column: 'reference_prefix',
        label: 'Reference prefix',
        help: 'References are issued as PREFIX-YEAR-NUMBER.',
      ),
      CmsField(column: 'gateway_provider', label: 'Gateway provider'),
      CmsField(column: 'gateway_checkout_url', label: 'Gateway checkout URL'),
      CmsField(column: 'gateway_public_key', label: 'Gateway public key'),
      CmsField(column: 'is_active', label: 'Active', kind: CmsFieldKind.toggle),
    ],
  ),
  CmsResource(
    name: 'events',
    singular: 'Event',
    plural: 'Events',
    icon: Icons.campaign_outlined,
    subtitleColumn: 'summary',
    description:
        'Conferences, summits, masterclasses and forums. Set the fee here and '
        'the registration page charges it — the amount is never editable by a '
        'registrant.',
    fields: [
      CmsField(column: 'title', label: 'Title', required: true),
      CmsField(
        column: 'theme',
        label: 'Theme',
        help:
            'The line the event is convened around, e.g. "Financing Africa\'s '
            'next decade of trade". Shown under the title.',
      ),
      CmsField(column: 'subtitle', label: 'Subtitle'),
      CmsField(
        column: 'event_type',
        label: 'Event type',
        kind: CmsFieldKind.select,
        options: [
          'CONFERENCE',
          'SUMMIT',
          'MASTERCLASS',
          'FORUM',
          'WORKSHOP',
          'WEBINAR',
          'NETWORKING',
          'OTHER',
        ],
      ),
      CmsField(
        column: 'summary',
        label: 'Short description',
        kind: CmsFieldKind.multiline,
        help: 'Shown on the events calendar and in social preview cards.',
      ),
      CmsField(
        column: 'description',
        label: 'Full description',
        kind: CmsFieldKind.richText,
      ),
      CmsField(
        column: 'why_attend',
        label: 'Why attend',
        kind: CmsFieldKind.multiline,
      ),
      CmsField(
        column: 'who_should_attend',
        label: 'Who should attend',
        kind: CmsFieldKind.multiline,
      ),
      CmsField(
        column: 'agenda',
        label: 'Agenda',
        kind: CmsFieldKind.stringList,
        help: 'One line per item, e.g. "09:00 Registration and coffee".',
      ),
      CmsField(
        column: 'highlights',
        label: 'Highlights',
        kind: CmsFieldKind.stringList,
        help: 'One per line. The short reasons somebody should attend.',
      ),
      CmsField(
        column: 'speakers',
        label: 'Speakers',
        kind: CmsFieldKind.stringList,
        help: 'One per line, e.g. "Dr Amina Bello — Director, Trade Policy".',
      ),
      CmsField(
        column: 'what_is_included',
        label: 'What the fee includes',
        kind: CmsFieldKind.multiline,
        help: 'Materials, meals, certificate — whatever the registrant gets.',
      ),
      CmsField(
        column: 'arrival_information',
        label: 'Arrival and access',
        kind: CmsFieldKind.multiline,
        help: 'Where to go, what time to arrive, parking, joining details.',
      ),
      CmsField(column: 'dress_code', label: 'Dress code'),
      CmsField(
        column: 'accreditation',
        label: 'Accreditation or CPD',
        kind: CmsFieldKind.multiline,
      ),
      CmsField(
        column: 'cancellation_policy',
        label: 'Cancellation and refunds',
        kind: CmsFieldKind.multiline,
      ),
      CmsField(
        column: 'registration_note',
        label: 'Note shown on the registration form',
        kind: CmsFieldKind.multiline,
        help: 'Read at the moment somebody is deciding. Keep it to a sentence.',
      ),
      CmsField(
        column: 'image_key',
        label: 'Banner image',
        kind: CmsFieldKind.image,
        help: 'Upload the event artwork. Also used for social preview cards.',
      ),
      CmsField(
        column: 'flier_key',
        label: 'Event flier',
        kind: CmsFieldKind.image,
        help:
            'Upload a flier or invitation (image or PDF) for people to '
            'download and forward.',
      ),
      CmsField(
        column: 'starts_at',
        label: 'Starts',
        kind: CmsFieldKind.dateTime,
      ),
      CmsField(
        column: 'ends_at',
        label: 'Ends',
        kind: CmsFieldKind.dateTime,
      ),
      CmsField(column: 'timezone', label: 'Timezone'),
      CmsField(column: 'venue', label: 'Venue'),
      CmsField(
        column: 'format',
        label: 'How to attend',
        kind: CmsFieldKind.select,
        // The stored values are fixed by a CHECK constraint on the table;
        // only the wording changes here. PHYSICAL is walk-in.
        options: ['PHYSICAL', 'ONLINE', 'HYBRID'],
        optionLabels: {
          'PHYSICAL': 'Walk-in',
          'ONLINE': 'Online',
          'HYBRID': 'Hybrid',
        },
      ),
      CmsField(
        column: 'registration_opens_at',
        label: 'Registration opens',
        kind: CmsFieldKind.dateTime,
        help:
            'Leave empty — the usual case — and registration opens the moment '
            'you publish. Set it only to put the event page up in advance and '
            'let bookings start later.',
      ),
      CmsField(
        column: 'registration_closes_at',
        label: 'Registration closes',
        kind: CmsFieldKind.dateTime,
        help: 'Leave empty to keep taking registrations until the event.',
      ),
      CmsField(
        column: 'registration_paused',
        label: 'Pause registration',
        kind: CmsFieldKind.toggle,
        help:
            'Stops new registrations while leaving the event page up. Use this '
            'rather than unpublishing, which hides the event from everyone who '
            'already has the link.',
      ),
      CmsField(
        column: 'capacity',
        label: 'Maximum participants',
        kind: CmsFieldKind.number,
        help: 'Leave empty for no limit.',
      ),
      CmsField(
        column: 'fee_amount',
        label: 'Registration fee',
        kind: CmsFieldKind.currency,
        help:
            'What one place costs. Zero means no payment is asked for and the '
            'registrant is confirmed as soon as the form is submitted.',
      ),
      CmsField(column: 'fee_currency', label: 'Currency'),
      // There is deliberately no payment-method field here. Which methods a
      // payer is offered — card, transfer, USSD — comes from the Flutterwave
      // account and the currency being charged, decided by the Worker at the
      // moment of payment. Setting it per event duplicated a decision
      // Flutterwave already holds, and got it wrong: a new event silently
      // offered nothing until somebody remembered to tick the boxes.
      CmsField(
        column: 'prices',
        label: 'Fee in other currencies',
        kind: CmsFieldKind.prices,
        help:
            'Switch on each currency you sell in and set the amount. Together '
            'with the fee above, this is what the event charges when it has no '
            'Registration fees rows — add those for an early bird rate, or '
            'different rates for attending in person and online.',
      ),
      CmsField(
        column: 'payment_instructions',
        label: 'Payment instructions',
        kind: CmsFieldKind.multiline,
        help:
            'Shown only when this deployment holds no Flutterwave credentials, '
            'so there is no online payment to offer. Normally left empty.',
      ),
      CmsField(column: 'contact_email', label: 'Event contact email'),
      CmsField(column: 'contact_phone', label: 'Event contact phone'),
      CmsField(
        column: 'terms',
        label: 'Terms and conditions',
        kind: CmsFieldKind.richText,
      ),
      CmsField(
        column: 'success_message',
        label: 'Registration success message',
        kind: CmsFieldKind.multiline,
      ),
      CmsField(
        column: 'allow_guest_registration',
        label: 'Allow registration without a WEA account',
        kind: CmsFieldKind.toggle,
        help: 'Recommended. Requiring an account first loses registrations.',
      ),
      CmsField(
        column: 'featured',
        label: 'Featured',
        kind: CmsFieldKind.toggle,
        help:
            'Marks this as a flagship event so it can be pulled out ahead of '
            'the rest. The events calendar does not treat it differently yet.',
      ),
      CmsField(
        column: 'status',
        label: 'Status',
        kind: CmsFieldKind.status,
        options: [
          'DRAFT',
          'PUBLISHED',
          'REGISTRATION_CLOSED',
          'COMPLETED',
          'CANCELLED',
          'ARCHIVED',
        ],
        help:
            'Published events accept registrations. Registration closed keeps '
            'the page up but takes no more.',
      ),
    ],
  ),
  CmsResource(
    name: 'event-prices',
    singular: 'Registration fee',
    plural: 'Registration fees',
    icon: Icons.sell_outlined,
    hasStatus: false,
    titleColumn: 'tier_label',
    subtitleColumn: 'attendance_mode',
    filterBy: ('event_id', 'events'),
    description:
        'One row per rate. A rate that ends on a date is an early bird; the '
        'row with no end date is what everyone pays afterwards. An event with '
        'no rows here keeps charging the fee set on the event itself, so '
        'nothing changes until you add one.',
    fields: [
      CmsField(
        column: 'event_id',
        label: 'Event',
        kind: CmsFieldKind.reference,
        referenceResource: 'events',
        required: true,
      ),
      CmsField(
        column: 'tier_label',
        label: 'Rate',
        required: true,
        help: 'Shown to the registrant, e.g. "Early Bird" or "Standard".',
      ),
      CmsField(
        column: 'attendance_mode',
        label: 'Applies to',
        kind: CmsFieldKind.select,
        options: ['ANY', 'PHYSICAL', 'VIRTUAL'],
        optionLabels: {
          'ANY': 'Everyone (event has one way to attend)',
          'PHYSICAL': 'Attending in person',
          'VIRTUAL': 'Attending online',
        },
        help:
            'Use Everyone unless the event format is Hybrid. A hybrid event '
            'needs one row per rate for each way of attending.',
      ),
      CmsField(
        column: 'prices',
        label: 'Price',
        kind: CmsFieldKind.prices,
        help:
            'One per line, e.g. "NGN 150000". Add a line per currency you sell '
            'in — WEA never converts, so a currency with no price here is '
            'simply not offered for this rate.',
      ),
      CmsField(
        column: 'available_from',
        label: 'Available from',
        kind: CmsFieldKind.dateTime,
        help: 'Leave empty to make it available as soon as booking opens.',
      ),
      CmsField(
        column: 'available_until',
        label: 'Available until',
        kind: CmsFieldKind.dateTime,
        help:
            'This is what makes a rate an early bird. Leave empty for the rate '
            'that applies once the others have closed. Where two rates are '
            'open at once, the one closing soonest is charged.',
      ),
    ],
  ),
  CmsResource(
    name: 'event-registration-fields',
    singular: 'Event question',
    plural: 'Event questions',
    icon: Icons.quiz_outlined,
    hasStatus: false,
    titleColumn: 'label',
    subtitleColumn: 'field_key',
    filterBy: ('event_id', 'events'),
    description:
        'Extra questions on an event registration form. Leave the event empty '
        'to ask it on every event. Keep the list short — a long form is the '
        'commonest reason a registration is abandoned.',
    fields: [
      CmsField(column: 'label', label: 'Question', required: true),
      CmsField(
        column: 'field_key',
        label: 'Key',
        required: true,
        help: 'Stable identifier, e.g. dietary_requirements. Do not change it later.',
      ),
      CmsField(
        column: 'event_id',
        label: 'Event',
        kind: CmsFieldKind.reference,
        referenceResource: 'events',
        help: 'Leave empty to ask this on every event.',
      ),
      CmsField(
        column: 'field_type',
        label: 'Answer type',
        kind: CmsFieldKind.select,
        options: ['TEXT', 'TEXTAREA', 'SELECT', 'CHECKBOX', 'DATE', 'NUMBER'],
      ),
      CmsField(
        column: 'options',
        label: 'Choices',
        kind: CmsFieldKind.stringList,
        help: 'One per line. Used when the answer type is SELECT.',
      ),
      CmsField(column: 'help_text', label: 'Help text'),
      CmsField(column: 'required', label: 'Required', kind: CmsFieldKind.toggle),
      CmsField(
        column: 'ask_early',
        label: 'Ask on the first step',
        kind: CmsFieldKind.toggle,
        help: 'Off by default, so the first screen stays short.',
      ),
    ],
  ),
  CmsResource(
    name: 'event-materials',
    singular: 'Event material',
    plural: 'Event materials',
    icon: Icons.folder_open_outlined,
    filterBy: ('event_id', 'events'),
    subtitleColumn: 'description',
    description:
        'Agendas, briefings and reading packs. Participant material is released '
        'only to registrations that have been paid for.',
    fields: [
      CmsField(
        column: 'event_id',
        label: 'Event',
        kind: CmsFieldKind.reference,
        referenceResource: 'events',
        required: true,
      ),
      CmsField(column: 'title', label: 'Title', required: true),
      CmsField(
        column: 'description',
        label: 'Description',
        kind: CmsFieldKind.multiline,
      ),
      CmsField(
        column: 'material_type',
        label: 'Type',
        kind: CmsFieldKind.select,
        options: [
          'DOCUMENT',
          'PRESENTATION',
          'BROCHURE',
          'AGENDA',
          'READING',
          'RECORDING',
          'LINK',
        ],
      ),
      CmsField(column: 'media_key', label: 'File', kind: CmsFieldKind.image),
      CmsField(column: 'resource_url', label: 'External link'),
      CmsField(
        column: 'visibility',
        label: 'Who can see it',
        kind: CmsFieldKind.select,
        options: ['PARTICIPANT', 'PUBLIC'],
      ),
      _statusField,
    ],
  ),
  CmsResource(
    name: 'event-sessions',
    singular: 'Event session',
    plural: 'Event sessions',
    icon: Icons.videocam_outlined,
    filterBy: ('event_id', 'events'),
    subtitleColumn: 'starts_at',
    description:
        'Live sittings of an event. Nobody is admitted until you switch the '
        'session live, whatever the clock says.',
    fields: [
      CmsField(
        column: 'event_id',
        label: 'Event',
        kind: CmsFieldKind.reference,
        referenceResource: 'events',
        required: true,
      ),
      CmsField(column: 'title', label: 'Title', required: true),
      CmsField(
        column: 'session_type',
        label: 'Type',
        kind: CmsFieldKind.select,
        options: ['LIVE', 'KEYNOTE', 'PANEL', 'WORKSHOP', 'BRIEFING'],
      ),
      CmsField(
        column: 'starts_at',
        label: 'Starts',
        kind: CmsFieldKind.dateTime,
      ),
      CmsField(
        column: 'ends_at',
        label: 'Ends',
        kind: CmsFieldKind.dateTime,
      ),
      CmsField(column: 'timezone', label: 'Timezone'),
      CmsField(
        column: 'room_name',
        label: 'Room name',
        help: 'Identifier for the live classroom. Never sent to the public.',
      ),
      CmsField(
        column: 'join_url',
        label: 'Join link',
        help:
            'Issued to paid participants only, one request at a time, once the '
            'session is live.',
      ),
      CmsField(column: 'recording_url', label: 'Recording link'),
      CmsField(column: 'speaker', label: 'Speaker'),
      CmsField(column: 'notes', label: 'Notes', kind: CmsFieldKind.multiline),
      CmsField(
        column: 'is_live',
        label: 'Session is live',
        kind: CmsFieldKind.toggle,
        help: 'Switch on to admit participants; switch off to close the room.',
      ),
      _statusField,
    ],
  ),
  CmsResource(
    name: 'share-links',
    singular: 'Campaign link',
    plural: 'Campaign links',
    icon: Icons.share_outlined,
    titleColumn: 'label',
    subtitleColumn: 'target_path',
    description:
        'Short links for promoting a page on LinkedIn, Facebook, YouTube, '
        'Google or anywhere else. Each one is counted separately, so you can '
        'see which channel actually produced registrations.',
    fields: [
      CmsField(
        column: 'label',
        label: 'Name',
        help: 'For your own reference, e.g. "Summit — LinkedIn launch".',
      ),
      CmsField(
        column: 'target_path',
        label: 'Page',
        required: true,
        help: 'Path on the public site, e.g. /events/africa-trade-summit',
      ),
      CmsField(
        column: 'target_type',
        label: 'Kind',
        kind: CmsFieldKind.select,
        options: ['EVENT', 'PROGRAMME', 'PAGE'],
      ),
      CmsField(
        column: 'channel',
        label: 'Channel',
        kind: CmsFieldKind.select,
        options: [
          'linkedin',
          'facebook',
          'youtube',
          'google',
          'x',
          'whatsapp',
          'instagram',
          'email',
          'newsletter',
          'partner',
        ],
      ),
      CmsField(
        column: 'medium',
        label: 'Medium',
        kind: CmsFieldKind.select,
        options: ['social', 'cpc', 'email', 'referral', 'video', 'display'],
      ),
      CmsField(
        column: 'campaign',
        label: 'Campaign',
        help: 'Groups links that belong to one push, e.g. summit-2026.',
      ),
      CmsField(
        column: 'code',
        label: 'Short code',
        help: 'Left empty, one is generated for you.',
      ),
      _statusField,
    ],
  ),
];

CmsResource cmsResourceByName(String name) =>
    cmsResources.firstWhere((resource) => resource.name == name);
