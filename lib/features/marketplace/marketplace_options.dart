import 'package:flutter/material.dart';

const productConditions = ['NEW', 'LIKE_NEW', 'GOOD', 'FAIR', 'POOR'];

class MarketplaceCategory {
  const MarketplaceCategory(this.name, this.icon, this.selectedIcon);
  final String name;
  final IconData icon;
  final IconData selectedIcon;
}

const marketplaceCategoryItems = [
  MarketplaceCategory('All', Icons.grid_view_outlined, Icons.grid_view_rounded),
  MarketplaceCategory(
    'Electronics',
    Icons.devices_other_outlined,
    Icons.devices_other_rounded,
  ),
  MarketplaceCategory(
    'Fashion',
    Icons.checkroom_outlined,
    Icons.checkroom_rounded,
  ),
  MarketplaceCategory(
    'Home & Furniture',
    Icons.chair_alt_outlined,
    Icons.chair_alt_rounded,
  ),
  MarketplaceCategory(
    'Vehicles',
    Icons.directions_bike_outlined,
    Icons.directions_bike_rounded,
  ),
  MarketplaceCategory(
    'Books & Hobbies',
    Icons.menu_book_outlined,
    Icons.menu_book_rounded,
  ),
];

// Kept so any existing code that uses the string list still works.
final marketplaceCategories = [
  for (final item in marketplaceCategoryItems) item.name,
];

List<MarketplaceCategory> marketplaceItemsForCategories(
  Iterable<String> names,
) {
  const all = MarketplaceCategory(
    'All',
    Icons.grid_view_outlined,
    Icons.grid_view_rounded,
  );
  const known = {
    'Electronics': MarketplaceCategory(
      'Electronics',
      Icons.devices_other_outlined,
      Icons.devices_other_rounded,
    ),
    'Fashion': MarketplaceCategory(
      'Fashion',
      Icons.checkroom_outlined,
      Icons.checkroom_rounded,
    ),
    'Home & Furniture': MarketplaceCategory(
      'Home & Furniture',
      Icons.chair_alt_outlined,
      Icons.chair_alt_rounded,
    ),
    'Vehicles': MarketplaceCategory(
      'Vehicles',
      Icons.directions_bike_outlined,
      Icons.directions_bike_rounded,
    ),
    'Books & Hobbies': MarketplaceCategory(
      'Books & Hobbies',
      Icons.menu_book_outlined,
      Icons.menu_book_rounded,
    ),
  };
  return [
    all,
    for (final name in names.where((name) => name.trim().isNotEmpty).toSet())
      known[name] ??
          MarketplaceCategory(
            name,
            Icons.category_outlined,
            Icons.category_rounded,
          ),
  ];
}
