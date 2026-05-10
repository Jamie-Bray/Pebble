import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/features/templates/data/models/template.dart';

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => TemplateRepository(),
);

class TemplateRepository {
  Future<List<Template>> loadTemplates() async {
    final data = await rootBundle.loadString('assets/seed/templates_en.json');
    final decoded = json.decode(data);
    if (decoded is! List) {
      return const <Template>[];
    }

    final templates = decoded
        .whereType<Map>()
        .map(
          (dynamic item) =>
              Template.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);

    return sortTemplatesForBrowse(templates);
  }
}

final templateCatalogProvider = FutureProvider<List<Template>>((ref) async {
  final repository = ref.watch(templateRepositoryProvider);
  return repository.loadTemplates();
});

final templateByIdProvider = Provider.family<AsyncValue<Template?>, String>((
  ref,
  id,
) {
  final asyncCatalog = ref.watch(templateCatalogProvider);
  return asyncCatalog.whenData((List<Template> templates) {
    for (final template in templates) {
      if (template.id == id) {
        return template;
      }
    }
    return null;
  });
});

List<Template> sortTemplatesForBrowse(Iterable<Template> templates) {
  final sorted = templates.toList(growable: false);
  sorted.sort((Template a, Template b) {
    final categoryOrder = _categorySortIndex(
      a.category,
    ).compareTo(_categorySortIndex(b.category));
    if (categoryOrder != 0) {
      return categoryOrder;
    }

    final templateOrder = _templateSortIndex(
      a.title,
    ).compareTo(_templateSortIndex(b.title));
    if (templateOrder != 0) {
      return templateOrder;
    }

    return a.title.compareTo(b.title);
  });
  return sorted;
}

Map<String, List<Template>> groupTemplatesByCategory(
  Iterable<Template> templates,
) {
  final grouped = <String, List<Template>>{};
  for (final category in Template.launchCategoryOrder) {
    final matches = templates
        .where((Template template) => template.category == category)
        .toList(growable: false);
    if (matches.isNotEmpty) {
      grouped[category] = matches;
    }
  }
  return grouped;
}

int _categorySortIndex(String category) {
  final index = Template.launchCategoryOrder.indexOf(category);
  if (index >= 0) {
    return index;
  }
  return Template.launchCategoryOrder.length;
}

int _templateSortIndex(String title) {
  final index = Template.launchTemplateTitleOrder.indexOf(title);
  if (index >= 0) {
    return index;
  }
  return Template.launchTemplateTitleOrder.length;
}
