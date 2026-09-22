class Category {
  final String id;
  final String name;
  final String description;
  final String icon;

  const Category({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });
}

class AppCategories {
  AppCategories._();

  static const List<Category> all = [
    Category(
      id: 'health_wellness',
      name: 'Health & Wellness',
      description: 'Discussions about health and personal wellbeing.',
      icon: 'health',
    ),
    Category(
      id: 'education',
      name: 'Education',
      description: 'Learning, studies, and educational experiences.',
      icon: 'education',
    ),
    Category(
      id: 'career_development',
      name: 'Career Development',
      description: 'Work, careers, skills, and professional growth.',
      icon: 'career',
    ),
    Category(
      id: 'personal_safety',
      name: 'Personal Safety',
      description: 'Safety, awareness, and experiences that matter.',
      icon: 'safety',
    ),
  ];

  static Category? fromId(String id) {
    for (final category in all) {
      if (category.id == id) {
        return category;
      }
    }

    return null;
  }
}