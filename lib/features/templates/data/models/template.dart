class Template {
  static final RegExp _photoMarkerPattern = RegExp(
    r'\s*\(\s*take\s+a\s+photo[^)]*\)\s*',
    caseSensitive: false,
  );

  static const List<String> launchCategoryOrder = <String>[
    'Leaving & Locking Up',
    'Daily Care',
    'Travel & Handovers',
  ];

  static const List<String> launchTemplateTitleOrder = <String>[
    'The Anxiety-Free Departure',
    'The Deep Sleep Bedtime Scan',
    'Car Security & Parking Peace',
    'The Big Trip Home Shutdown',
    'The “Did I take it?” Med Check',
    'Morning Pet Routine',
    'Essential School Morning Run',
    'The Toddler “Survival” Bag',
    'The “No Item Left Behind” Hotel Checkout',
    'The Office/Workspace “Switch-Off”',
    'Gym & Sports Prep',
    'The “House Sitter” Handover',
  ];

  const Template({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.goodFor,
    required this.searchTerms,
    required this.steps,
    this.featuredRank,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String goodFor;
  final List<String> searchTerms;
  final List<String> steps;
  final int? featuredRank;

  int get stepCount => steps.length;
  int get photoRequiredCount => steps.where(stepRequiresPhoto).length;
  bool get isFeatured => featuredRank != null;

  static bool stepRequiresPhoto(String step) {
    return _photoMarkerPattern.hasMatch(step);
  }

  static String cleanStepLabel(String step) {
    final cleaned = step
        .replaceAll(_photoMarkerPattern, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? step.trim() : cleaned;
  }

  Template copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? goodFor,
    List<String>? searchTerms,
    List<String>? steps,
    int? featuredRank,
    bool clearFeaturedRank = false,
  }) {
    return Template(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      goodFor: goodFor ?? this.goodFor,
      searchTerms: searchTerms ?? this.searchTerms,
      steps: steps ?? this.steps,
      featuredRank: clearFeaturedRank
          ? null
          : featuredRank ?? this.featuredRank,
    );
  }

  bool matchesQuery(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    final haystacks = <String>[
      title,
      description,
      category,
      goodFor,
      ...searchTerms,
      ...steps,
    ];

    return haystacks.any((value) => value.toLowerCase().contains(normalized));
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'goodFor': goodFor,
      'searchTerms': searchTerms,
      'steps': steps,
      'featuredRank': featuredRank,
    };
  }

  factory Template.fromJson(Map<String, dynamic> json) {
    return Template(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      goodFor: json['goodFor'] as String? ?? '',
      searchTerms: _readStringList(json['searchTerms']),
      steps: _readStringList(json['steps']),
      featuredRank: (json['featuredRank'] as num?)?.toInt(),
    );
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .map((dynamic item) => item?.toString().trim() ?? '')
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
