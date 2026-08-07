import '../models/public_content.dart';

/// Development-only content until the public CMS is connected in a later module.
abstract final class PublicContentService {
  static const programmes = [
    Programme(
      id: 'leadership-governance',
      category: 'LEADERSHIP & GOVERNANCE',
      title: 'Executive Leadership & Governance',
      summary:
          'Lead with judgement, institutional awareness and strategic clarity.',
      duration: '12 weeks',
      deliveryMode: 'Blended',
      imageUrl:
          'https://images.unsplash.com/photo-1556761175-b413da4baf72?auto=format&fit=crop&w=1100&q=82',
    ),
    Programme(
      id: 'corporate-finance',
      category: 'FINANCE',
      title: 'Corporate Finance for Executives',
      summary:
          'A practical executive perspective on capital, value and financial decision-making.',
      duration: '10 weeks',
      deliveryMode: 'Online + live',
      imageUrl:
          'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=1100&q=82',
    ),
    Programme(
      id: 'emerging-markets',
      category: 'STRATEGY',
      title: 'Strategic Management in Emerging Markets',
      summary:
          'Build strategy that works across fast-changing African and global markets.',
      duration: '10 weeks',
      deliveryMode: 'Blended',
      imageUrl:
          'https://images.unsplash.com/photo-1556761175-5973dc0f32e7?auto=format&fit=crop&w=1100&q=82',
    ),
    Programme(
      id: 'policy-reform',
      category: 'POLICY',
      title: 'Public Policy & Institutional Reform',
      summary:
          'Translate public purpose into credible policy and institutional change.',
      duration: '12 weeks',
      deliveryMode: 'Online + live',
      imageUrl:
          'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?auto=format&fit=crop&w=1100&q=82',
    ),
    Programme(
      id: 'women-leadership',
      category: 'LEADERSHIP & GOVERNANCE',
      title: 'Women in Executive Leadership',
      summary:
          'A focused space for influence, governance and leadership at senior levels.',
      duration: '8 weeks',
      deliveryMode: 'Blended',
      imageUrl:
          'https://images.unsplash.com/photo-1521737711867-e3b97375f902?auto=format&fit=crop&w=1100&q=82',
    ),
    Programme(
      id: 'digital-transformation',
      category: 'DIGITAL TRANSFORMATION',
      title: 'Digital Transformation for Executives',
      summary:
          'Make deliberate technology decisions that strengthen organisations and people.',
      duration: '8 weeks',
      deliveryMode: 'Online + live',
      imageUrl:
          'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1100&q=82',
    ),
    Programme(
      id: 'africa-trade-investment',
      category: 'TRADE & INVESTMENT',
      title: 'Africa Trade & Investment Executive Certificate',
      summary:
          'Advance cross-border trade, regional integration and sustainable investment.',
      duration: '16 weeks',
      deliveryMode: 'Blended',
      imageUrl:
          'https://images.unsplash.com/photo-1504274066651-8d31a536b11a?auto=format&fit=crop&w=1400&q=82',
      featured: true,
    ),
  ];

  static const faculty = [
    FacultyMember(
      name: 'Faculty profile to be announced',
      role: 'Executive Practice Faculty',
      expertise: 'Leadership & Governance',
      note:
          'Illustrative profile — final faculty information will be confirmed by WEA.',
      imageUrl:
          'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=800&q=82',
    ),
    FacultyMember(
      name: 'Faculty profile to be announced',
      role: 'Executive Practice Faculty',
      expertise: 'Trade & Investment',
      note:
          'Illustrative profile — final faculty information will be confirmed by WEA.',
      imageUrl:
          'https://images.unsplash.com/photo-1556761175-4b46a572b786?auto=format&fit=crop&w=800&q=82',
    ),
    FacultyMember(
      name: 'Faculty profile to be announced',
      role: 'Executive Practice Faculty',
      expertise: 'Policy & Institutions',
      note:
          'Illustrative profile — final faculty information will be confirmed by WEA.',
      imageUrl:
          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=800&q=82',
    ),
  ];

  static const events = [
    WEAEvent(
      date: 'OCT 2026',
      title: 'Africa Trade & Investment Summit',
      format: 'Accra + online',
      description:
          'A forthcoming forum on trade, investment and regional opportunity. Details to be confirmed.',
      imageUrl:
          'https://images.unsplash.com/photo-1511578314322-379afb476865?auto=format&fit=crop&w=900&q=82',
    ),
    WEAEvent(
      date: 'NOV 2026',
      title: 'Executive Roundtable',
      format: 'Online',
      description:
          'A forthcoming conversation for senior leaders. Details to be confirmed.',
      imageUrl:
          'https://images.unsplash.com/photo-1497366811353-6870744d04b2?auto=format&fit=crop&w=900&q=82',
    ),
    WEAEvent(
      date: 'DEC 2026',
      title: 'Policy Dialogue',
      format: 'Nairobi + online',
      description: 'A forthcoming policy dialogue. Details to be confirmed.',
      imageUrl:
          'https://images.unsplash.com/photo-1521295121783-8a321d551ad2?auto=format&fit=crop&w=900&q=82',
    ),
  ];

  static const research = [
    ResearchItem(
      category: 'POLICY BRIEF',
      title: 'Regional integration and executive decision-making',
      summary:
          'A forthcoming WEA policy brief on the choices shaping African markets.',
      date: 'COMING SOON',
    ),
    ResearchItem(
      category: 'EXECUTIVE INSIGHT',
      title: 'Leadership for institutions in transition',
      summary:
          'A forthcoming executive perspective on governing through complexity.',
      date: 'COMING SOON',
    ),
    ResearchItem(
      category: 'TRADE INTELLIGENCE',
      title: 'The practical agenda for cross-border growth',
      summary:
          'A forthcoming WEA insight for leaders working across African economies.',
      date: 'COMING SOON',
    ),
  ];
}
