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
  date,
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
    this.referenceResource,
    this.referenceLabelColumn = 'title',
  });

  final String column;
  final String label;
  final CmsFieldKind kind;
  final String help;
  final bool required;
  final List<String> options;

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
        kind: CmsFieldKind.date,
        help: 'ISO date and time, e.g. 2026-09-14T14:00:00Z',
      ),
      CmsField(column: 'ends_at', label: 'Ends', kind: CmsFieldKind.date),
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
];

CmsResource cmsResourceByName(String name) =>
    cmsResources.firstWhere((resource) => resource.name == name);
