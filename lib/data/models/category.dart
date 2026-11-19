class Category {
  const Category({
    required this.id,
    required this.name,
    required this.shortName,
    required this.description,
  });

  final String id;
  final String name;

  /// Used on chips and small labels.
  final String shortName;
  final String description;
}

class AppCategories {
  AppCategories._();

  static const List<Category> all = [
    Category(
      id: 'health_wellness',
      name: 'Health & Wellness',
      shortName: 'Health',
      description: 'Health, body and mental wellbeing.',
    ),
    Category(
      id: 'education',
      name: 'Education',
      shortName: 'Education',
      description: 'Studies, scholarships and learning.',
    ),
    Category(
      id: 'career_development',
      name: 'Career Development',
      shortName: 'Career',
      description: 'Work, interviews, pay and growth.',
    ),
    Category(
      id: 'personal_safety',
      name: 'Personal Safety',
      shortName: 'Safety',
      description: 'Staying safe and what to do when you are not.',
    ),
    Category(
      id: askLoomaId,
      name: 'Ask Looma Team',
      shortName: 'Ask Looma',
      description: 'Questions for the team. Answers appear as Looma Team.',
    ),
  ];

  /// Questions for the team; moderators answer as "Looma Team".
  static const String askLoomaId = 'ask_looma';

  static Category? fromId(String id) {
    for (final category in all) {
      if (category.id == id) return category;
    }
    return null;
  }
}
