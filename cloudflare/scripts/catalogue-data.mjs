// The initial WEA catalogue.
//
// This is *seed* data, not the source of truth. Once deployed, every value here
// is editable by a Super Admin through the CMS; nothing in the application
// reads this file at runtime. It exists so the platform launches with the real
// academy catalogue rather than an empty database.

export const programmeTypes = [
  {
    slug: 'executive-certificate',
    title: 'Executive Certificate',
    pluralTitle: 'Executive Certificates',
    description:
      'Structured, assessed programmes leading to a WEA Advanced Certificate.',
    defaults: {
      level: 'Advanced Executive',
      duration: '12 weeks',
      delivery: 'Blended',
      tuition: 1450,
      cpd: 30,
      award: 'WEA Advanced Executive Certificate',
    },
  },
  {
    slug: 'masterclass',
    title: 'Masterclass',
    pluralTitle: 'Masterclasses',
    description:
      'Intensive executive sessions led by senior practitioners, focused on a single decision area.',
    defaults: {
      level: 'Executive',
      duration: '1 day',
      delivery: 'Live online',
      tuition: 340,
      cpd: 6,
      award: 'WEA Masterclass Certificate of Participation',
    },
  },
  {
    slug: 'short-course',
    title: 'Short Course',
    pluralTitle: 'Short Courses',
    description:
      'Focused, practical courses that build a specific professional capability.',
    defaults: {
      level: 'Professional',
      duration: '4 weeks',
      delivery: 'Online',
      tuition: 220,
      cpd: 8,
      award: 'WEA Certificate of Completion',
    },
  },
  {
    slug: 'advanced-executive-programme',
    title: 'Advanced Executive Programme',
    pluralTitle: 'Advanced Executive Programmes',
    description:
      'The academy’s flagship multi-module programmes for senior leaders and policymakers.',
    defaults: {
      level: 'Senior Executive',
      duration: '16 weeks',
      delivery: 'Blended',
      tuition: 2950,
      cpd: 45,
      award: 'WEA Advanced Executive Programme Certificate',
    },
  },
  {
    slug: 'executive-short-case',
    title: 'Executive Short Case',
    pluralTitle: 'Executive Short Cases',
    description:
      'Short, decision-centred cases drawn from real African business and policy situations.',
    defaults: {
      level: 'Executive',
      duration: '90 minutes',
      delivery: 'Online',
      tuition: 95,
      cpd: 2,
      award: 'WEA Executive Short Case Record',
    },
  },
];

const IMG =
  'https://images.unsplash.com/photo-%s?auto=format&fit=crop&w=1400&q=82';
const img = (id) => IMG.replace('%s', id);

export const areas = [
  {
    code: '01',
    slug: 'international-trade-investment',
    title: 'International Trade & Investment',
    tagline: 'Trade, AfCFTA, investment and cross-border commerce',
    summary:
      'Develop the strategic knowledge and practical capability required to navigate cross-border commerce, African market integration, investment and international business.',
    description:
      'Africa’s continental market is being built in real time. This area equips executives, trade professionals, investors and policymakers to work confidently across borders — from AfCFTA rules of origin and trade documentation to investment promotion, trade finance and international commercial negotiation.',
    image: img('1504274066651-8d31a536b11a'),
    modules: [
      'The AfCFTA legal and institutional framework',
      'Cross-border trade and trade facilitation',
      'Regional economic communities in practice',
      'Export development and market access',
      'Investment promotion and public–private partnership',
      'Trade finance and cross-border payments',
    ],
    groups: [
      {
        type: 'executive-certificate',
        items: ['Advanced Certificate in International Trade & Investment'],
      },
      {
        type: 'masterclass',
        items: [
          'AfCFTA Business Opportunities Masterclass',
          'Mastering Cross-Border Trade in Africa',
          'Investment Attraction & Investor Relations',
          'International Commercial Negotiation',
          'Trade Finance for Executives',
          'Managing Cross-Border Commercial Risk',
          'Digital Trade & the Future of African Commerce',
        ],
      },
      {
        type: 'short-course',
        items: [
          'Understanding AfCFTA',
          'Export Readiness',
          'Import & Export Compliance',
          'International Contract Management',
          'Trade Documentation',
          'Trade Finance Fundamentals',
          'Cross-Border Payments',
          'Investment Promotion',
          'Market Entry Strategy',
          'International Business Negotiation',
        ],
      },
      {
        type: 'advanced-executive-programme',
        items: [
          'Executive Programme on African Trade, Investment and Cross-Border Business',
        ],
      },
    ],
  },
  {
    code: '02',
    slug: 'banking-finance-financial-services',
    title: 'Banking, Finance & Financial Services',
    tagline: 'Banking leadership, regulation, risk and financial innovation',
    summary:
      'Build the judgement required to lead financial institutions through regulation, risk, digital transformation and rising consumer expectations.',
    description:
      'Financial services sit at the centre of Africa’s economic transition. This area develops banking executives, regulators, risk professionals and fintech leaders across governance, compliance, financial crime, digital banking and the responsible use of artificial intelligence in credit and customer decisions.',
    image: img('1554224155-6726b3ff858f'),
    modules: [
      'Strategy and governance in financial institutions',
      'Banking regulation and supervisory expectations',
      'Credit, market and operational risk',
      'Financial crime, fraud and compliance',
      'Digital banking, payments and fintech partnerships',
      'Financial consumer protection and conduct',
    ],
    groups: [
      {
        type: 'executive-certificate',
        items: [
          'Advanced Certificate in Banking Leadership & Financial Services',
          'Advanced Certificate in Banking Regulation, Compliance & Risk',
          'Advanced Certificate in Digital Banking & Financial Innovation',
        ],
      },
      {
        type: 'masterclass',
        items: [
          'Strategic Leadership for Banking Executives',
          'Banking Compliance & Regulatory Risk',
          'Anti-Financial Crime & Risk Management',
          'Digital Banking Transformation',
          'AI in Banking',
          'Cyber Risk for Financial Institutions',
          'Customer Experience in Banking',
          'Financial Consumer Protection',
          'Fintech Partnerships & Open Banking',
          'Executive Decision-Making in Banking',
        ],
      },
      {
        type: 'short-course',
        items: [
          'Credit Risk',
          'Operational Risk',
          'Compliance Management',
          'Corporate Governance',
          'Financial Consumer Protection Practice',
          'Digital Payments',
          'Fintech',
          'AI for Banking Professionals',
          'Customer Experience in Financial Services',
          'Data Governance',
          'Fraud Risk Management',
          'Regulatory Technology',
        ],
      },
      {
        type: 'advanced-executive-programme',
        items: [
          'Executive Programme on the Future of Banking, Fintech, AI and Financial Consumer Protection',
        ],
      },
    ],
  },
  {
    code: '03',
    slug: 'retail-consumer-markets-customer-experience',
    title: 'Retail, Consumer Markets & Customer Experience',
    tagline: 'Retail strategy, consumer intelligence and customer experience',
    summary:
      'Understand how African consumers behave, and build retail and service organisations that earn their trust and keep it.',
    description:
      'Retail and consumer markets are where strategy meets everyday reality. This area covers retail leadership, omnichannel strategy, consumer intelligence, complaint and dispute handling, e-commerce and the operational discipline behind a genuinely good customer experience.',
    image: img('1441986300917-64674bd600d8'),
    modules: [
      'Retail strategy in African consumer markets',
      'Consumer behaviour and consumer intelligence',
      'Customer experience design and measurement',
      'Omnichannel and e-commerce operations',
      'Complaint handling and dispute resolution',
      'Retail risk, compliance and brand trust',
    ],
    groups: [
      {
        type: 'executive-certificate',
        items: [
          'Advanced Certificate in Retail Management & Consumer Intelligence',
          'Advanced Certificate in Customer Experience & Consumer Protection',
        ],
      },
      {
        type: 'masterclass',
        items: [
          'The Future of Retail in Africa',
          'Consumer Intelligence for Business Growth',
          'Customer Experience Transformation',
          'Retail Risk & Compliance',
          'E-Commerce & Consumer Protection',
          'Consumer Data & Personalisation',
          'Managing Difficult Customers and Consumer Disputes',
          'Building Consumer Trust',
          'Retail Leadership',
          'Omnichannel Retail Strategy',
        ],
      },
      {
        type: 'short-course',
        items: [
          'Consumer Behaviour',
          'Retail Operations',
          'Customer Experience Fundamentals',
          'Complaint Management',
          'Consumer Data Analytics',
          'E-Commerce',
          'Digital Customer Service',
          'Consumer Rights in Retail',
          'Retail Compliance',
          'Customer Retention',
          'Brand Trust',
          'Social Commerce',
        ],
      },
      {
        type: 'advanced-executive-programme',
        items: [
          'Executive Programme on Consumer Intelligence, Retail Transformation & Customer Experience',
        ],
      },
    ],
  },
  {
    code: '04',
    slug: 'consumer-protection-consumer-intelligence',
    title: 'Consumer Protection & Consumer Intelligence',
    tagline: 'A signature WEA area, backed by the World United Consumer Organisation',
    summary:
      'Build the regulatory literacy and analytical capability to protect consumers and to run a business that deserves their confidence.',
    description:
      'Consumer protection is WEA’s signature discipline, reflecting the institutional mandate of the World United Consumer Organisation. This area addresses consumer rights, complaint and dispute systems, product safety, advertising standards, digital market conduct and the fast-moving question of consumer rights in an age of automated decisions.',
    image: img('1521737711867-e3b97375f902'),
    modules: [
      'Consumer protection law and regulatory practice',
      'Consumer complaints, redress and dispute resolution',
      'Consumer intelligence and market analytics',
      'Product safety and unfair commercial practices',
      'Consumer protection in digital and AI-driven markets',
      'Building a consumer-centric organisation',
    ],
    groups: [
      {
        type: 'executive-certificate',
        items: [
          'Advanced Certificate in Consumer Protection & Regulatory Practice',
          'Advanced Certificate in Consumer Intelligence & Market Analytics',
          'Advanced Certificate in Consumer Affairs Management',
        ],
      },
      {
        type: 'masterclass',
        items: [
          'Consumer Protection for Corporate Executives',
          'Consumer Intelligence for Strategic Decision-Making',
          'Managing Consumer Complaints & Disputes',
          'Consumer Protection in Digital Markets',
          'AI and Consumer Rights',
          'E-Commerce Consumer Protection',
          'Building Consumer Trust in Regulated Markets',
          'Consumer Risk Management',
          'Consumer-Centric Business Strategy',
        ],
      },
      {
        type: 'short-course',
        items: [
          'Consumer Rights',
          'Consumer Complaint Management',
          'Alternative Dispute Resolution',
          'Consumer Data',
          'Product Safety',
          'Advertising & Consumer Protection',
          'Digital Consumer Protection',
          'Unfair Commercial Practices',
          'Consumer Risk',
          'Consumer Advocacy',
        ],
      },
      {
        type: 'advanced-executive-programme',
        items: [
          'Executive Programme on Consumer Protection, Intelligence, Digital Markets and Responsible Business',
        ],
      },
    ],
  },
  {
    code: '05',
    slug: 'artificial-intelligence-digital-transformation',
    title: 'Artificial Intelligence, Digital Transformation & Responsible AI',
    tagline: 'AI strategy, governance and responsible adoption',
    summary:
      'Lead the adoption of artificial intelligence with judgement — capturing the advantage while governing the risk.',
    description:
      'Artificial intelligence is reshaping how organisations decide, serve and compete. This area prepares executives, regulators and professionals to set AI strategy, govern AI risk, meet emerging regulatory expectations, and apply AI responsibly across banking, retail, trade, legal practice and public administration.',
    image: img('1518770660439-4636190af475'),
    modules: [
      'Artificial intelligence for executive decision-makers',
      'AI strategy and digital transformation',
      'AI governance, ethics and emerging regulation',
      'AI risk management and assurance',
      'Data governance for AI systems',
      'Responsible AI in customer and consumer decisions',
    ],
    groups: [
      {
        type: 'executive-certificate',
        items: [
          'Advanced Certificate in AI for Business Leaders',
          'Advanced Certificate in AI Governance, Ethics & Regulation',
          'Advanced Certificate in Digital Transformation & AI Strategy',
        ],
      },
      {
        type: 'masterclass',
        items: [
          'AI for CEOs and Board Members',
          'AI for Government Executives',
          'Generative AI for Business',
          'AI Risk Management',
          'Responsible AI',
          'AI Governance',
          'AI and Consumer Protection',
          'AI in Banking Operations',
          'AI in Retail',
          'AI in International Trade',
          'AI for Lawyers and Legal Professionals',
          'AI for Public Administration',
        ],
      },
      {
        type: 'short-course',
        items: [
          'Generative AI for Professionals',
          'Prompt Engineering for Executives',
          'AI Productivity',
          'AI Research & Intelligence',
          'AI-Assisted Decision-Making',
          'AI and Data Governance',
          'AI Ethics',
          'AI Risk',
          'AI for Customer Service',
          'AI for Marketing',
          'AI for HR',
          'AI for Legal Practice',
        ],
      },
      {
        type: 'advanced-executive-programme',
        items: [
          'Executive Programme on Artificial Intelligence, Digital Transformation and Responsible Governance',
        ],
      },
    ],
  },
  {
    code: '06',
    slug: 'executive-short-case-series',
    title: 'Executive Short Case Series',
    tagline: 'Short, decision-centred cases from real African situations',
    summary:
      'Practise the decision itself. Each short case puts you inside a real situation with incomplete information and a deadline.',
    description:
      'The Executive Short Case Series is a distinct WEA format: compact, intensive cases built around a single executive decision. Participants work through the situation, defend a position and compare it with how the decision was actually handled.',
    image: img('1526628953301-3e589a6a8b74'),
    modules: [],
    groups: [
      {
        type: 'executive-short-case',
        items: [
          'A Nigerian Retailer Faces a Consumer Data Crisis',
          'A Bank Introduces an AI Credit-Scoring System',
          'A Fintech Company Enters a New African Market',
          'A Foreign Investor Wants to Enter Nigeria',
          'A Consumer Complaint Goes Viral on Social Media',
          'An African Exporter Encounters a Cross-Border Trade Barrier',
          'AI Generates a Discriminatory Business Decision',
          'A Bank Faces a Major Customer-Trust Crisis',
          'A Retailer Uses Consumer Data Without Adequate Transparency',
          'Government Must Regulate a New AI-Based Consumer Platform',
        ],
      },
    ],
  },
];

/// Faculty seeded so programme pages are not empty on day one.
export const faculty = [
  {
    slug: 'amina-yusuf',
    name: 'Dr. Amina Yusuf',
    role: 'Executive Faculty — Leadership & Governance',
    organisation: 'WUCO Executive Academy',
    bio: 'Board adviser and former group executive, working with African institutions on governance, executive decision quality and organisational change.',
    expertise: ['Executive leadership', 'Corporate governance', 'Organisational change'],
    image: img('1573496359142-b8d87734a5a2'),
  },
  {
    slug: 'kwame-mensah',
    name: 'Prof. Kwame Mensah',
    role: 'Executive Faculty — Regulation & Risk',
    organisation: 'WUCO Executive Academy',
    bio: 'Academic and practitioner in financial regulation, supervisory practice and enterprise risk across West African markets.',
    expertise: ['Banking regulation', 'Enterprise risk', 'Compliance'],
    image: img('1507003211169-0a1dd7228f2d'),
  },
  {
    slug: 'nadia-okonkwo',
    name: 'Dr. Nadia Okonkwo',
    role: 'Executive Faculty — Finance',
    organisation: 'WUCO Executive Academy',
    bio: 'Corporate financier advising on capital structure, valuation and investment appraisal for growth businesses and development institutions.',
    expertise: ['Corporate finance', 'Valuation', 'Investment appraisal'],
    image: img('1580489944761-15a19d654956'),
  },
  {
    slug: 'selassie-bekele',
    name: 'Prof. Selassie Bekele',
    role: 'Executive Faculty — Trade & Investment',
    organisation: 'WUCO Executive Academy',
    bio: 'Trade economist working on AfCFTA implementation, regional integration and cross-border investment strategy.',
    expertise: ['AfCFTA', 'Regional integration', 'Investment strategy'],
    image: img('1519085360753-af0119f7cbe7'),
  },
  {
    slug: 'chidinma-eze',
    name: 'Barr. Chidinma Eze',
    role: 'Executive Faculty — Consumer Protection',
    organisation: 'World United Consumer Organisation',
    bio: 'Consumer protection lawyer and regulator, specialising in redress systems, digital market conduct and consumer rights in automated decisions.',
    expertise: ['Consumer protection', 'Dispute resolution', 'Digital markets'],
    image: img('1531123897727-8f129e1688ce'),
  },
  {
    slug: 'tunde-adeyemi',
    name: 'Tunde Adeyemi',
    role: 'Executive Faculty — Artificial Intelligence',
    organisation: 'WUCO Executive Academy',
    bio: 'Technology executive advising boards on AI strategy, AI governance and the responsible deployment of automated decision systems.',
    expertise: ['AI strategy', 'AI governance', 'Digital transformation'],
    image: img('1552058544-f2b08422138a'),
  },
];

/// Faculty attached to each area's programmes.
export const areaFaculty = {
  'international-trade-investment': ['selassie-bekele', 'nadia-okonkwo'],
  'banking-finance-financial-services': ['kwame-mensah', 'nadia-okonkwo'],
  'retail-consumer-markets-customer-experience': ['chidinma-eze', 'amina-yusuf'],
  'consumer-protection-consumer-intelligence': ['chidinma-eze', 'kwame-mensah'],
  'artificial-intelligence-digital-transformation': ['tunde-adeyemi', 'amina-yusuf'],
  'executive-short-case-series': ['amina-yusuf', 'tunde-adeyemi'],
};
