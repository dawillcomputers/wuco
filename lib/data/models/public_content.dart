class Programme {
  const Programme({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.duration,
    required this.deliveryMode,
    required this.imageUrl,
    this.featured = false,
  });

  final String id;
  final String category;
  final String title;
  final String summary;
  final String duration;
  final String deliveryMode;
  final String imageUrl;
  final bool featured;
}

class FacultyMember {
  const FacultyMember({
    required this.name,
    required this.role,
    required this.expertise,
    required this.note,
    required this.imageUrl,
  });

  final String name;
  final String role;
  final String expertise;
  final String note;
  final String imageUrl;
}

class WEAEvent {
  const WEAEvent({
    required this.date,
    required this.title,
    required this.format,
    required this.description,
    required this.imageUrl,
  });

  final String date;
  final String title;
  final String format;
  final String description;
  final String imageUrl;
}

class ResearchItem {
  const ResearchItem({
    required this.category,
    required this.title,
    required this.summary,
    required this.date,
  });

  final String category;
  final String title;
  final String summary;
  final String date;
}
