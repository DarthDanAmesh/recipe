import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/services.dart';

class AppCoordinator extends ChangeNotifier {
  // ============================================================================
  // SERVICES
  // ============================================================================
  final VisionService _vision = VisionService();
  final FirebaseService _firebase = FirebaseService();
  final RecipeApiService _recipeApi = RecipeApiService();
  final LocationService _location = LocationService();
  final ImagePickerService _imagePicker = ImagePickerService();

  // ============================================================================
  // STATE
  // ============================================================================
  List<Ingredient> _inventory = [];
  List<Recipe> _recipes = [];
  List<ShoppingItem> _shoppingList = [];
  List<Store> _nearbyStores = [];
  Position? _currentPosition;
  UserPreferences _preferences = UserPreferences();
  
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _successMessage;

  // ============================================================================
  // GETTERS
  // ============================================================================
  List<Ingredient> get inventory => List.unmodifiable(_inventory);
  List<Recipe> get recipes => List.unmodifiable(_recipes);
  List<ShoppingItem> get shoppingList => List.unmodifiable(_shoppingList);
  List<Store> get nearbyStores => List.unmodifiable(_nearbyStores);
  Position? get currentPosition => _currentPosition;
  UserPreferences get preferences => _preferences;
  
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  
  int get unpurchasedCount => _shoppingList.where((item) => !item.isPurchased).length;
  int get expiringCount => _inventory.where((item) => item.willExpireSoon).length;
  
  List<Ingredient> get expiringIngredients => 
      _inventory.where((item) => item.willExpireSoon).toList();
  
  List<ShoppingItem> get unpurchasedItems => 
      _shoppingList.where((item) => !item.isPurchased).toList();

  // ============================================================================
  // INITIALIZATION
  // ============================================================================
  AppCoordinator() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _setLoading(true);
      
      // Initialize Firebase
      await _firebase.init();
      
      // Sign in anonymously if not authenticated
      if (!_firebase.isAuthenticated) {
        await _firebase.signInAnonymously();
      }
      
      // Load local data
      await _loadInventory();
      await _loadShoppingList();
      await _loadPreferences();
      
      // Try to get location (non-blocking)
      _loadLocationInBackground();
      
      _isInitialized = true;
      _setLoading(false);
    } catch (e, stackTrace) {
      _handleError(e, 'Initialization', stackTrace);
    }
  }

  Future<void> _loadLocationInBackground() async {
    try {
      _currentPosition = await _location.getCurrentPosition();
      _nearbyStores = await _location.findNearbyStores(_currentPosition!);
      notifyListeners();
    } catch (e) {
      print('Location failed (non-critical): $e');
    }
  }

  // ============================================================================
  // MAIN PIPELINE: IMAGE -> INVENTORY -> RECIPES -> SHOPPING LIST
  // ============================================================================
  Future<void> processImageFromCamera() async {
    try {
      final imagePath = await _imagePicker.pickImageFromCamera();
      if (imagePath != null) {
        await processImageToShoppingList(imagePath);
      }
    } catch (e, stackTrace) {
      _handleError(e, 'Camera', stackTrace);
    }
  }

  Future<void> processImageFromGallery() async {
    try {
      final imagePath = await _imagePicker.pickImageFromGallery();
      if (imagePath != null) {
        await processImageToShoppingList(imagePath);
      }
    } catch (e, stackTrace) {
      _handleError(e, 'Gallery', stackTrace);
    }
  }

  Future<void> processImageToShoppingList(String imagePath) async {
    _setLoading(true);
    _clearMessages();

    try {
      // STEP 1: OCR - Extract text from image
      final rawTextItems = await _vision.recognizeText(imagePath);
      
      if (rawTextItems.isEmpty) {
        throw Exception('No food items detected in image. Try again with better lighting.');
      }
      
      // STEP 2: Update Inventory
      final newIngredients = rawTextItems.map((text) => Ingredient(
        id: const Uuid().v4(),
        name: text,
        category: _categorizeIngredient(text),
        dateAdded: DateTime.now(),
      )).toList();
      
      await _addIngredients(newIngredients);
      
      // STEP 3: Fetch Recipes (if API enabled)
      if (_firebase.isApiEnabled) {
        final ingredientNames = _inventory
            .map((ing) => ing.name)
            .take(10) // Limit to avoid API overload
            .toList();
        
        _recipes = await _recipeApi.fetchRecipesByIngredients(ingredientNames);
        
        // Calculate match percentages
        for (var recipe in _recipes) {
          recipe.matchPercentage = _calculateMatchPercentage(recipe);
        }
        
        _recipes.sort((a, b) => b.matchPercentage.compareTo(a.matchPercentage));
      } else {
        _setError('Recipe API disabled by admin. Using offline mode.');
      }
      
      // STEP 4: Auto-generate shopping list from best recipe
      if (_recipes.isNotEmpty) {
        await generateShoppingListFromRecipe(_recipes.first);
      }
      
      _setSuccess('Scanned ${newIngredients.length} items! Found ${_recipes.length} recipes.');
      
    } catch (e, stackTrace) {
      _handleError(e, 'Image Processing', stackTrace);
    } finally {
      _setLoading(false);
    }
  }

  int _calculateMatchPercentage(Recipe recipe) {
    final inventoryNames = _inventory.map((i) => i.name.toLowerCase()).toSet();
    final recipeIngredients = recipe.ingredients.map((i) => i.toLowerCase()).toList();
    
    int matches = 0;
    for (var ingredient in recipeIngredients) {
      if (inventoryNames.any((inv) => ingredient.contains(inv) || inv.contains(ingredient))) {
        matches++;
      }
    }
    
    return ((matches / recipeIngredients.length) * 100).round();
  }

  // ============================================================================
  // INVENTORY MANAGEMENT
  // ============================================================================
  Future<void> _loadInventory() async {
    try {
      final box = await Hive.openBox<Ingredient>('inventory');
      _inventory = box.values.toList();
      _checkExpirations();
      notifyListeners();
    } catch (e) {
      print('Failed to load inventory: $e');
    }
  }

  Future<void> _addIngredients(List<Ingredient> ingredients) async {
    try {
      final box = await Hive.openBox<Ingredient>('inventory');
      
      for (var ingredient in ingredients) {
        await box.put(ingredient.id, ingredient);
      }
      
      await _loadInventory();
      
      // Sync to Firebase
      if (_firebase.isAuthenticated) {
        await _firebase.saveUserInventory(_inventory);
      }
    } catch (e) {
      print('Failed to add ingredients: $e');
      rethrow;
    }
  }

  Future<void> addIngredient(String name, {
    DateTime? expiryDate,
    String category = 'Manual',
    double quantity = 1.0,
    String unit = 'unit',
  }) async {
    final ingredient = Ingredient(
      id: const Uuid().v4(),
      name: name,
      expiryDate: expiryDate,
      category: category,
      quantity: quantity,
      unit: unit,
      dateAdded: DateTime.now(),
    );
    
    await _addIngredients([ingredient]);
    _setSuccess('Added $name to inventory');
  }

  Future<void> removeIngredient(String id) async {
    try {
      final box = await Hive.openBox<Ingredient>('inventory');
      await box.delete(id);
      await _loadInventory();
      _setSuccess('Ingredient removed');
    } catch (e) {
      _handleError(e, 'Remove Ingredient');
    }
  }

  Future<void> updateIngredient(Ingredient ingredient) async {
    try {
      final box = await Hive.openBox<Ingredient>('inventory');
      await box.put(ingredient.id, ingredient);
      await _loadInventory();
      _setSuccess('Ingredient updated');
    } catch (e) {
      _handleError(e, 'Update Ingredient');
    }
  }

  Future<void> clearInventory() async {
    try {
      final box = await Hive.openBox<Ingredient>('inventory');
      await box.clear();
      _inventory = [];
      notifyListeners();
      _setSuccess('Inventory cleared');
    } catch (e) {
      _handleError(e, 'Clear Inventory');
    }
  }

  void _checkExpirations() {
    for (var ingredient in _inventory) {
      if (ingredient.expiryDate != null) {
        ingredient.isExpired = ingredient.expiryDate!.isBefore(DateTime.now());
      }
    }
  }

  // ============================================================================
  // SHOPPING LIST MANAGEMENT
  // ============================================================================
  Future<void> _loadShoppingList() async {
    try {
      final box = await Hive.openBox<ShoppingItem>('shopping_list');
      _shoppingList = box.values.toList();
      notifyListeners();
    } catch (e) {
      print('Failed to load shopping list: $e');
    }
  }

  Future<void> generateShoppingListFromRecipe(Recipe recipe) async {
    try {
      final inventoryNames = _inventory.map((i) => i.name.toLowerCase()).toSet();
      
      final missingIngredients = recipe.ingredients
          .where((ing) => !inventoryNames.any((inv) => 
              ing.toLowerCase().contains(inv) || inv.contains(ing.toLowerCase())))
          .toList();
      
      final box = await Hive.openBox<ShoppingItem>('shopping_list');
      
      for (var ingredient in missingIngredients) {
        final item = ShoppingItem(
          id: const Uuid().v4(),
          name: ingredient,
          category: _categorizeIngredient(ingredient),
          recipeId: recipe.id,
        );
        await box.put(item.id, item);
      }
      
      await _loadShoppingList();
      _setSuccess('Shopping list generated from ${recipe.title}');
    } catch (e) {
      _handleError(e, 'Generate Shopping List');
    }
  }

  Future<void> addShoppingItem(String name, {
    double quantity = 1.0,
    String unit = 'unit',
  }) async {
    try {
      final item = ShoppingItem(
        id: const Uuid().v4(),
        name: name,
        quantity: quantity,
        unit: unit,
        category: _categorizeIngredient(name),
      );
      
      final box = await Hive.openBox<ShoppingItem>('shopping_list');
      await box.put(item.id, item);
      await _loadShoppingList();
      _setSuccess('Added to shopping list');
    } catch (e) {
      _handleError(e, 'Add Shopping Item');
    }
  }

  Future<void> toggleShoppingItemPurchased(String id) async {
    try {
      final box = await Hive.openBox<ShoppingItem>('shopping_list');
      final item = box.get(id);
      
      if (item != null) {
        item.isPurchased = !item.isPurchased;
        await box.put(id, item);
        await _loadShoppingList();
      }
    } catch (e) {
      _handleError(e, 'Toggle Shopping Item');
    }
  }

  Future<void> removeShoppingItem(String id) async {
    try {
      final box = await Hive.openBox<ShoppingItem>('shopping_list');
      await box.delete(id);
      await _loadShoppingList();
    } catch (e) {
      _handleError(e, 'Remove Shopping Item');
    }
  }

  Future<void> clearPurchasedItems() async {
    try {
      final box = await Hive.openBox<ShoppingItem>('shopping_list');
      final purchased = _shoppingList.where((item) => item.isPurchased).toList();
      
      for (var item in purchased) {
        await box.delete(item.id);
      }
      
      await _loadShoppingList();
      _setSuccess('Cleared ${purchased.length} purchased items');
    } catch (e) {
      _handleError(e, 'Clear Purchased Items');
    }
  }

  // ============================================================================
  // PREFERENCES
  // ============================================================================
  Future<void> _loadPreferences() async {
    try {
      final box = await Hive.openBox<UserPreferences>('preferences');
      _preferences = box.get('user_prefs', defaultValue: UserPreferences())!;
      notifyListeners();
    } catch (e) {
      print('Failed to load preferences: $e');
    }
  }

  Future<void> updatePreferences(UserPreferences newPrefs) async {
    try {
      final box = await Hive.openBox<UserPreferences>('preferences');
      await box.put('user_prefs', newPrefs);
      _preferences = newPrefs;
      notifyListeners();
      _setSuccess('Preferences saved');
    } catch (e) {
      _handleError(e, 'Update Preferences');
    }
  }

  // ============================================================================
  // HELPERS
  // ============================================================================
  String _categorizeIngredient(String name) {
    final lower = name.toLowerCase();
    
    if (RegExp(r'milk|cheese|yogurt|butter|cream').hasMatch(lower)) {
      return 'Dairy';
    } else if (RegExp(r'chicken|beef|pork|fish|meat').hasMatch(lower)) {
      return 'Protein';
    } else if (RegExp(r'apple|banana|orange|berry|fruit').hasMatch(lower)) {
      return 'Fruits';
    } else if (RegExp(r'lettuce|spinach|carrot|broccoli|vegetable').hasMatch(lower)) {
      return 'Vegetables';
    } else if (RegExp(r'bread|pasta|rice|cereal|flour').hasMatch(lower)) {
      return 'Grains';
    }
    
    return 'Other';
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _successMessage = null;
    notifyListeners();
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = null;
    notifyListeners();
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void _handleError(dynamic error, String context, [StackTrace? stackTrace]) {
    _setError(error.toString());
    _firebase.logError(error, context, stackTrace: stackTrace);
    debugPrint('Error in $context: $error');
    if (stackTrace != null) debugPrint('Stack trace: $stackTrace');
  }

  @override
  void dispose() {
    _vision.dispose();
    super.dispose();
  }
}