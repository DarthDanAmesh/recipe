import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart'; // run the following: dart run build_runner build or dart run build_runner build --delete-conflicting-outputs

// ============================================================================
// INGREDIENT MODEL
// ============================================================================
@HiveType(typeId: 0)
class Ingredient extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime? expiryDate;

  @HiveField(3)
  String category;

  @HiveField(4)
  double quantity;

  @HiveField(5)
  String unit;

  @HiveField(6)
  DateTime dateAdded;

  @HiveField(7)
  bool isExpired;

  Ingredient({
    required this.id,
    required this.name,
    this.expiryDate,
    this.category = 'Uncategorized',
    this.quantity = 1.0,
    this.unit = 'unit',
    DateTime? dateAdded,
    this.isExpired = false,
  }) : dateAdded = dateAdded ?? DateTime.now();

  bool get willExpireSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 3 && daysUntilExpiry >= 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'expiryDate': expiryDate?.toIso8601String(),
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'dateAdded': dateAdded.toIso8601String(),
    'isExpired': isExpired,
  };

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    id: json['id'] as String,
    name: json['name'] as String,
    expiryDate: json['expiryDate'] != null 
        ? DateTime.parse(json['expiryDate'] as String) 
        : null,
    category: json['category'] as String? ?? 'Uncategorized',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    unit: json['unit'] as String? ?? 'unit',
    dateAdded: json['dateAdded'] != null 
        ? DateTime.parse(json['dateAdded'] as String)
        : DateTime.now(),
    isExpired: json['isExpired'] as bool? ?? false,
  );
}

// ============================================================================
// RECIPE MODEL
// ============================================================================
@HiveType(typeId: 1)
@JsonSerializable()
class Recipe extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  List<String> ingredients;

  @HiveField(3)
  String instructions;

  @HiveField(4)
  String? imageUrl;

  @HiveField(5)
  int prepTimeMinutes;

  @HiveField(6)
  int cookTimeMinutes;

  @HiveField(7)
  int servings;

  @HiveField(8)
  List<String> tags;

  @HiveField(9)
  double rating;

  @HiveField(10)
  int matchPercentage;

  Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.instructions,
    this.imageUrl,
    this.prepTimeMinutes = 0,
    this.cookTimeMinutes = 0,
    this.servings = 1,
    this.tags = const [],
    this.rating = 0.0,
    this.matchPercentage = 0,
  });

  Map<String, dynamic> toJson() => _$RecipeToJson(this);
  factory Recipe.fromJson(Map<String, dynamic> json) => _$RecipeFromJson(json);

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;
}

// ============================================================================
// SHOPPING LIST ITEM
// ============================================================================
@HiveType(typeId: 2)
class ShoppingItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double quantity;

  @HiveField(3)
  String unit;

  @HiveField(4)
  bool isPurchased;

  @HiveField(5)
  String category;

  @HiveField(6)
  DateTime dateAdded;

  @HiveField(7)
  String? recipeId;

  ShoppingItem({
    required this.id,
    required this.name,
    this.quantity = 1.0,
    this.unit = 'unit',
    this.isPurchased = false,
    this.category = 'Uncategorized',
    DateTime? dateAdded,
    this.recipeId,
  }) : dateAdded = dateAdded ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'isPurchased': isPurchased,
    'category': category,
    'dateAdded': dateAdded.toIso8601String(),
    'recipeId': recipeId,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: json['id'] as String,
    name: json['name'] as String,
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    unit: json['unit'] as String? ?? 'unit',
    isPurchased: json['isPurchased'] as bool? ?? false,
    category: json['category'] as String? ?? 'Uncategorized',
    dateAdded: json['dateAdded'] != null
        ? DateTime.parse(json['dateAdded'] as String)
        : DateTime.now(),
    recipeId: json['recipeId'] as String?,
  );
}

// ============================================================================
// STORE MODEL
// ============================================================================
enum StoreType { supermarket, grocery, pharmacy, specialty, farmers_market }

class Store {
  final String id;
  final String name;
  final StoreType type;
  final double latitude;
  final double longitude;
  final String address;
  final double? distance; // in kilometers
  final String? phoneNumber;
  final bool isOpen;

  Store({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.distance,
    this.phoneNumber,
    this.isOpen = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.toString(),
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'distance': distance,
    'phoneNumber': phoneNumber,
    'isOpen': isOpen,
  };

  factory Store.fromJson(Map<String, dynamic> json) => Store(
    id: json['id'] as String,
    name: json['name'] as String,
    type: StoreType.values.firstWhere(
      (e) => e.toString() == json['type'],
      orElse: () => StoreType.supermarket,
    ),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    address: json['address'] as String,
    distance: (json['distance'] as num?)?.toDouble(),
    phoneNumber: json['phoneNumber'] as String?,
    isOpen: json['isOpen'] as bool? ?? true,
  );
}

// ============================================================================
// USER PREFERENCES
// ============================================================================
@HiveType(typeId: 3)
class UserPreferences extends HiveObject {
  @HiveField(0)
  List<String> dietaryRestrictions;

  @HiveField(1)
  List<String> allergies;

  @HiveField(2)
  List<String> dislikedIngredients;

  @HiveField(3)
  bool notifyExpiringSoon;

  @HiveField(4)
  int expiryWarningDays;

  @HiveField(5)
  String preferredUnits; // 'metric' or 'imperial'

  UserPreferences({
    this.dietaryRestrictions = const [],
    this.allergies = const [],
    this.dislikedIngredients = const [],
    this.notifyExpiringSoon = true,
    this.expiryWarningDays = 3,
    this.preferredUnits = 'metric',
  });
}