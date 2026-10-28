import 'package:easy_localization/easy_localization.dart';

const _knownConditions = {'NEW', 'LIKE_NEW', 'GOOD', 'FAIR', 'POOR'};

const _knownCategories = {
  'All': 'categories.all',
  'Electronics': 'categories.electronics',
  'Fashion': 'categories.fashion',
  'Home & Furniture': 'categories.homeFurniture',
  'Vehicles': 'categories.vehicles',
  'Books & Hobbies': 'categories.booksHobbies',
};

String conditionLabel(String? value) {
  final raw = (value ?? '').trim();
  final code = raw.toUpperCase().replaceAll(' ', '_');
  if (_knownConditions.contains(code)) return 'condition.$code'.tr();
  return raw.isEmpty ? '—' : raw.replaceAll('_', ' ');
}

String categoryLabel(String? value) {
  final raw = (value ?? '').trim();
  final key = _knownCategories[raw];
  return key == null ? raw : key.tr();
}
