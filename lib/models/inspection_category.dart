// inspection_category.dart
import 'inspection_item.dart';

class InspectionCategory {
  final String name;
  final String description;
  final List<InspectionItem> items;

  InspectionCategory({
    required this.name,
    required this.description,
    required this.items,
  });
}