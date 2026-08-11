import '../domain/catalogue_models.dart';
import '../domain/registration_models.dart';
import 'catalogue_repository.dart';

/// Offline catalogue used when no API is configured.
///
/// A representative slice of the real catalogue, not the whole of it: enough
/// for the public site and registration flow to be exercised without a backend.
/// Nothing here is a production path — the seeded database is the real content.
class MockCatalogueRepository implements CatalogueRepository {
  MockCatalogueRepository();

  static const _image =
      'https://images.unsplash.com/photo-1504274066651-8d31a536b11a?auto=format&fit=crop&w=1400&q=82';

  Future<T> _latency<T>(T value) =>
      Future.delayed(const Duration(milliseconds: 220), () => value);

  final _areas = <Map<String, dynamic>>[
    {
      'id': 'area-trade',
      'slug': 'international-trade-investment',
      'code': '01',
      'title': 'International Trade & Investment',
      'tagline': 'Trade, AfCFTA, investment and cross-border commerce',
      'summary':
          'Develop the strategic knowledge and practical capability required to navigate cross-border commerce, African market integration, investment and international business.',
      'description':
          'Africa’s continental market is being built in real time. This area equips executives to work confidently across borders.',
      'image_url': _image,
      'programme_count': 3,
    },
    {
      'id': 'area-banking',
      'slug': 'banking-finance-financial-services',
      'code': '02',
      'title': 'Banking, Finance & Financial Services',
      'tagline': 'Banking leadership, regulation, risk and financial innovation',
      'summary':
          'Build the judgement required to lead financial institutions through regulation, risk and digital transformation.',
      'description':
          'Financial services sit at the centre of Africa’s economic transition.',
      'image_url':
          'https://images.unsplash.com/photo-1554224155-6726b3ff858f?auto=format&fit=crop&w=1400&q=82',
      'programme_count': 2,
    },
    {
      'id': 'area-ai',
      'slug': 'artificial-intelligence-digital-transformation',
      'code': '05',
      'title': 'Artificial Intelligence, Digital Transformation & Responsible AI',
      'tagline': 'AI strategy, governance and responsible adoption',
      'summary':
          'Lead the adoption of artificial intelligence with judgement — capturing the advantage while governing the risk.',
      'description':
          'Artificial intelligence is reshaping how organisations decide, serve and compete.',
      'image_url':
          'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1400&q=82',
      'programme_count': 2,
    },
  ];

  final _types = <Map<String, dynamic>>[
    {
      'id': 'type-cert',
      'slug': 'executive-certificate',
      'title': 'Executive Certificate',
      'plural_title': 'Executive Certificates',
      'description': 'Structured, assessed programmes leading to a WEA Advanced Certificate.',
    },
    {
      'id': 'type-masterclass',
      'slug': 'masterclass',
      'title': 'Masterclass',
      'plural_title': 'Masterclasses',
      'description': 'Intensive executive sessions focused on a single decision area.',
    },
    {
      'id': 'type-short',
      'slug': 'short-course',
      'title': 'Short Course',
      'plural_title': 'Short Courses',
      'description': 'Focused, practical courses that build a specific capability.',
    },
  ];

  late final _programmes = <Map<String, dynamic>>[
    _programme(
      slug: 'advanced-certificate-in-international-trade-and-investment',
      title: 'Advanced Certificate in International Trade & Investment',
      area: _areas[0],
      type: _types[0],
      summary:
          'An assessed executive certificate in international trade and investment, developed for senior professionals working across African and global markets.',
      tuition: 1450,
      duration: '12 weeks',
      featured: true,
    ),
    _programme(
      slug: 'afcfta-business-opportunities-masterclass',
      title: 'AfCFTA Business Opportunities Masterclass',
      area: _areas[0],
      type: _types[1],
      summary:
          'A one-day executive masterclass on the commercial opportunities created by the African Continental Free Trade Area.',
      tuition: 340,
      duration: '1 day',
    ),
    _programme(
      slug: 'export-readiness',
      title: 'Export Readiness',
      area: _areas[0],
      type: _types[2],
      summary:
          'A focused short course building practical capability in export readiness for businesses entering new markets.',
      tuition: 220,
      duration: '4 weeks',
    ),
    _programme(
      slug: 'advanced-certificate-in-banking-leadership-and-financial-services',
      title: 'Advanced Certificate in Banking Leadership & Financial Services',
      area: _areas[1],
      type: _types[0],
      summary:
          'An assessed executive certificate for leaders accountable for strategy, risk and conduct in financial institutions.',
      tuition: 1450,
      duration: '12 weeks',
      featured: true,
    ),
    _programme(
      slug: 'ai-in-banking',
      title: 'AI in Banking',
      area: _areas[1],
      type: _types[1],
      summary:
          'A masterclass on applying artificial intelligence in credit, service and risk decisions without losing regulatory footing.',
      tuition: 340,
      duration: '1 day',
    ),
    _programme(
      slug: 'advanced-certificate-in-ai-governance-ethics-and-regulation',
      title: 'Advanced Certificate in AI Governance, Ethics & Regulation',
      area: _areas[2],
      type: _types[0],
      summary:
          'An assessed executive certificate in governing artificial intelligence responsibly across an organisation.',
      tuition: 1450,
      duration: '12 weeks',
      featured: true,
    ),
    _programme(
      slug: 'generative-ai-for-professionals',
      title: 'Generative AI for Professionals',
      area: _areas[2],
      type: _types[2],
      summary:
          'A short course that turns generative AI from a curiosity into a dependable part of professional work.',
      tuition: 220,
      duration: '4 weeks',
    ),
  ];

  Map<String, dynamic> _programme({
    required String slug,
    required String title,
    required Map<String, dynamic> area,
    required Map<String, dynamic> type,
    required String summary,
    required double tuition,
    required String duration,
    bool featured = false,
  }) => {
    'id': 'prog-$slug',
    'slug': slug,
    'title': title,
    'subtitle': area['tagline'],
    'summary': summary,
    'description':
        '$summary Delivered by WUCO Executive Academy and backed by the institutional authority of the World United Consumer Organisation.',
    'image_url': area['image_url'],
    'level': 'Executive',
    'duration_label': duration,
    'delivery_mode': 'Blended',
    'language': 'English',
    'certificate_award': 'WEA ${type['title']}',
    'eligibility':
        'Open to professionals with relevant working experience. No formal academic prerequisite.',
    'who_should_attend':
        'Executives, managers, regulators, entrepreneurs and policymakers working in the field.',
    'learning_outcomes': [
      'Apply the material directly to decisions you are accountable for',
      'Weigh commercial, regulatory and reputational consequences together',
      'Lead change across teams, institutions and borders',
    ],
    'tuition_amount': tuition,
    'tuition_currency': 'USD',
    'cpd_points': 30,
    'registration_open': 1,
    'featured': featured ? 1 : 0,
    'area_id': area['id'],
    'area_slug': area['slug'],
    'area_title': area['title'],
    'type_id': type['id'],
    'type_slug': type['slug'],
    'type_title': type['title'],
  };

  final _registrations = <RegistrationRecord>[];

  @override
  Future<CatalogueOverview> overview() => _latency(
    CatalogueOverview.fromMap({
      'areas': _areas,
      'types': _types,
      'settings': const <String, String>{},
    }),
  );

  @override
  Future<AreaDetail> area(String slug) {
    final area = _areas.firstWhere(
      (row) => row['slug'] == slug || row['id'] == slug,
      orElse: () => throw const CatalogueFailure(CatalogueFailureKind.notFound),
    );
    return _latency(
      AreaDetail.fromMap({
        'area': area,
        'programmes': [
          for (final programme in _programmes)
            if (programme['area_id'] == area['id']) programme,
        ],
      }),
    );
  }

  @override
  Future<List<CatalogueProgramme>> programmes({
    String? area,
    String? type,
    String? query,
    bool featuredOnly = false,
    int? limit,
  }) {
    final term = query?.trim().toLowerCase() ?? '';
    final matches = [
      for (final row in _programmes)
        if ((area == null || area.isEmpty || row['area_slug'] == area) &&
            (type == null || type.isEmpty || row['type_slug'] == type) &&
            (!featuredOnly || row['featured'] == 1) &&
            (term.isEmpty ||
                '${row['title']}'.toLowerCase().contains(term) ||
                '${row['summary']}'.toLowerCase().contains(term)))
          CatalogueProgramme.fromMap(row),
    ];
    return _latency(limit == null ? matches : matches.take(limit).toList());
  }

  @override
  Future<ProgrammeDetail> programme(String slug) {
    final row = _programmes.firstWhere(
      (item) => item['slug'] == slug || item['id'] == slug,
      orElse: () => throw const CatalogueFailure(CatalogueFailureKind.notFound),
    );
    return _latency(
      ProgrammeDetail.fromMap({
        'programme': row,
        'modules': [
          for (var index = 0; index < 4; index++)
            {
              'id': 'mod-$index',
              'number': index + 1,
              'title': const [
                'Foundations and framing',
                'Core analytical tools',
                'Applied decision-making',
                'Executive capstone',
              ][index],
              'summary': '',
              'duration_label': '${2 + (index % 2)} weeks',
              'lessons': const <Map<String, dynamic>>[],
            },
        ],
        'faculty': const [
          {
            'id': 'fac-1',
            'slug': 'amina-yusuf',
            'name': 'Dr. Amina Yusuf',
            'role_title': 'Executive Faculty',
            'organisation': 'WUCO Executive Academy',
            'bio':
                'Board adviser and former group executive working with African institutions on governance and executive decision quality.',
            'expertise': ['Executive leadership', 'Governance'],
            'role': 'Programme Director',
          },
        ],
        'sessions': const <Map<String, dynamic>>[],
      }),
    );
  }

  @override
  Future<List<FacultyProfile>> faculty() => _latency(const []);

  @override
  Future<List<PaymentMethod>> paymentMethods() => _latency([
    PaymentMethod.fromMap(const {
      'id': 'pay-bank-transfer',
      'slug': 'bank-transfer',
      'kind': 'BANK_TRANSFER',
      'title': 'Bank transfer',
      'instructions':
          'Transfer the tuition amount and quote your WEA registration reference exactly as shown.',
      'currency': 'USD',
      'account_name': 'WUCO Executive Academy',
    }),
  ]);

  @override
  Future<RegistrationContext> registrationContext(String programmeId) =>
      _latency(
        RegistrationContext.fromMap(const {
          'known': {
            'first_name': '',
            'last_name': '',
            'email': '',
            'phone': '',
            'country': '',
          },
          'missing_profile': <String>[],
          'profile_complete': true,
          'fields': [
            {
              'id': 'f1',
              'field_key': 'organisation',
              'label': 'Organisation',
              'field_type': 'TEXT',
              'required': 1,
              'options': <String>[],
              'help_text': 'The organisation you represent.',
            },
            {
              'id': 'f2',
              'field_key': 'job_title',
              'label': 'Job title',
              'field_type': 'TEXT',
              'required': 1,
              'options': <String>[],
              'help_text': '',
            },
          ],
        }),
      );

  @override
  Future<RegistrationRecord> register({
    required String programmeId,
    required Map<String, String> answers,
    String? paymentMethodId,
  }) {
    final programme = _programmes.firstWhere(
      (item) => item['id'] == programmeId || item['slug'] == programmeId,
      orElse: () => throw const CatalogueFailure(CatalogueFailureKind.notFound),
    );
    final record = RegistrationRecord(
      id: 'reg-${_registrations.length + 1}',
      reference:
          'WEA-${DateTime.now().year}-${(_registrations.length + 1).toString().padLeft(5, '0')}',
      programmeTitle: '${programme['title']}',
      programmeSlug: '${programme['slug']}',
      status: RegistrationStatus.awaitingPayment,
      currency: 'USD',
      createdAt: DateTime.now(),
      amount: (programme['tuition_amount'] as num).toDouble(),
      answers: answers,
    );
    _registrations.add(record);
    return _latency(record);
  }

  @override
  Future<List<RegistrationRecord>> myRegistrations() =>
      _latency(List.unmodifiable(_registrations));
}
