import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

// ============================================================================
// VISION SERVICE - OCR with ML Kit
// ============================================================================
class VisionService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final List<String> _foodKeywords = [
    'milk', 'egg', 'bread', 'cheese', 'butter', 'chicken', 'beef', 'pork',
    'fish', 'rice', 'pasta', 'potato', 'tomato', 'onion', 'garlic', 'carrot',
    'apple', 'banana', 'orange', 'lettuce', 'spinach', 'broccoli', 'yogurt',
    'flour', 'sugar', 'salt', 'pepper', 'oil', 'sauce', 'juice', 'water',
  ];

  Future<List<String>> recognizeText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = 
          await _textRecognizer.processImage(inputImage);
      
      // Extract and filter text
      final allText = recognizedText.blocks
          .map((block) => block.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();
      
      // Filter for food items using fuzzy matching
      final foodItems = _extractFoodItems(allText);
      
      return foodItems;
    } catch (e) {
      print('Vision error: $e');
      rethrow;
    }
  }

  List<String> _extractFoodItems(List<String> rawText) {
    final foodItems = <String>[];
    
    for (var text in rawText) {
      final normalized = text.toLowerCase().trim();
      
      // Skip numbers, prices, dates
      if (RegExp(r'^\d+\.?\d*$').hasMatch(normalized)) continue;
      if (RegExp(r'\$|€|£|price|total|tax').hasMatch(normalized)) continue;
      if (RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(normalized)) continue;
      
      // Check if contains food keywords
      final containsFood = _foodKeywords.any((keyword) => 
          normalized.contains(keyword));
      
      if (containsFood || normalized.split(' ').length <= 3) {
        // Clean up the text
        var cleaned = normalized
            .replaceAll(RegExp(r'[^a-z\s]'), '')
            .trim();
        
        if (cleaned.isNotEmpty && cleaned.length > 2) {
          foodItems.add(_capitalize(cleaned));
        }
      }
    }
    
    return foodItems.toSet().toList(); // Remove duplicates
  }

  String _capitalize(String text) {
    return text.split(' ').map((word) => 
        word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

// ============================================================================
// FIREBASE SERVICE
// ============================================================================
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final RemoteConfig _remoteConfig = RemoteConfig.instance;

  User? get currentUser => _auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  Future<void> init() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      await _remoteConfig.setDefaults({
        'api_enabled': true,
        'max_recipe_calls_per_day': 50,
        'enable_location_services': true,
      });
      
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      print('Firebase init error: $e');
    }
  }

  bool get isApiEnabled => _remoteConfig.getBool('api_enabled');
  int get maxRecipeCallsPerDay => _remoteConfig.getInt('max_recipe_calls_per_day');

  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      print('Anonymous sign-in error: $e');
      rethrow;
    }
  }

  Future<void> logError(dynamic error, String context, {StackTrace? stackTrace}) async {
    try {
      if (currentUser != null) {
        await _db.collection('errors').add({
          'timestamp': FieldValue.serverTimestamp(),
          'error': error.toString(),
          'context': context,
          'stackTrace': stackTrace?.toString(),
          'userId': currentUser!.uid,
          'platform': Platform.isIOS ? 'iOS' : 'Android',
        });
      }
    } catch (e) {
      print('Failed to log error: $e');
    }
  }

  Future<void> saveUserInventory(List<Ingredient> inventory) async {
    if (currentUser == null) return;
    
    try {
      final batch = _db.batch();
      final userDoc = _db.collection('users').doc(currentUser!.uid);
      
      for (var ingredient in inventory) {
        final ingredientRef = userDoc.collection('inventory').doc(ingredient.id);
        batch.set(ingredientRef, ingredient.toJson());
      }
      
      await batch.commit();
    } catch (e) {
      print('Failed to save inventory: $e');
    }
  }

  Stream<List<Ingredient>> watchInventory() {
    if (currentUser == null) return Stream.value([]);
    
    return _db
        .collection('users')
        .doc(currentUser!.uid)
        .collection('inventory')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ingredient.fromJson(doc.data()))
            .toList());
  }
}

// ============================================================================
// RECIPE API SERVICE - Real Spoonacular Integration
// ============================================================================
class RecipeApiService {
  final Dio _dio = Dio();
  
  // You'll need to get your own API key from https://spoonacular.com/food-api
  static const String _apiKey = 'YOUR_SPOONACULAR_API_KEY_HERE';
  static const String _baseUrl = 'https://api.spoonacular.com';

  Future<List<Recipe>> fetchRecipesByIngredients(
    List<String> ingredients, {
    int number = 10,
  }) async {
    try {
      // If no API key, return mock data
      if (_apiKey == 'YOUR_SPOONACULAR_API_KEY_HERE') {
        return _generateMockRecipes(ingredients);
      }

      final response = await _dio.get(
        '$_baseUrl/recipes/findByIngredients',
        queryParameters: {
          'apiKey': _apiKey,
          'ingredients': ingredients.join(','),
          'number': number,
          'ranking': 2, // Maximize used ingredients
          'ignorePantry': false,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        
        final recipes = await Future.wait(
          data.take(5).map((item) => _fetchRecipeDetails(item['id']))
        );
        
        return recipes.whereType<Recipe>().toList();
      }

      return _generateMockRecipes(ingredients);
    } catch (e) {
      print('Recipe API error: $e');
      return _generateMockRecipes(ingredients);
    }
  }

  Future<Recipe?> _fetchRecipeDetails(int id) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/recipes/$id/information',
        queryParameters: {'apiKey': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        return Recipe(
          id: data['id'].toString(),
          title: data['title'],
          ingredients: (data['extendedIngredients'] as List)
              .map((ing) => ing['original'] as String)
              .toList(),
          instructions: data['instructions'] ?? 'No instructions available',
          imageUrl: data['image'],
          prepTimeMinutes: data['preparationMinutes'] ?? 0,
          cookTimeMinutes: data['cookingMinutes'] ?? 0,
          servings: data['servings'] ?? 1,
          rating: (data['spoonacularScore'] ?? 0.0) / 20.0,
          tags: (data['dishTypes'] as List?)?.map((e) => e.toString()).toList() ?? [],
        );
      }
    } catch (e) {
      print('Recipe details error: $e');
    }
    return null;
  }

  List<Recipe> _generateMockRecipes(List<String> ingredients) {
    final random = Random();
    final recipeTitles = [
      '${ingredients.isNotEmpty ? ingredients.first : "Mixed"} Delight',
      'Gourmet ${ingredients.isNotEmpty ? ingredients.first : "Surprise"}',
      'Quick ${ingredients.isNotEmpty ? ingredients.first : "Meal"} Stir-Fry',
      'Homemade ${ingredients.isNotEmpty ? ingredients.first : "Special"}',
    ];

    return List.generate(min(recipeTitles.length, 3), (index) {
      return Recipe(
        id: const Uuid().v4(),
        title: recipeTitles[index],
        ingredients: [
          ...ingredients.take(3),
          'Salt',
          'Pepper',
          'Olive Oil',
          'Garlic',
        ],
        instructions: '''
1. Prepare all ingredients by washing and chopping.
2. Heat a large pan with olive oil over medium heat.
3. Add garlic and sauté for 1 minute.
4. Add main ingredients and cook for 10-15 minutes.
5. Season with salt and pepper to taste.
6. Serve hot and enjoy!
        '''.trim(),
        prepTimeMinutes: 10 + random.nextInt(20),
        cookTimeMinutes: 15 + random.nextInt(30),
        servings: 2 + random.nextInt(4),
        rating: 3.5 + random.nextDouble() * 1.5,
        tags: ['Quick', 'Easy', 'Homemade'],
        matchPercentage: 60 + random.nextInt(40),
      );
    });
  }
}

// ============================================================================
// LOCATION SERVICE
// ============================================================================
class LocationService {
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }

  Future<List<Store>> findNearbyStores(Position position) async {
    // Mock store data - In production, integrate with Google Places API
    final mockStores = [
      Store(
        id: '1',
        name: 'Whole Foods Market',
        type: StoreType.supermarket,
        latitude: position.latitude + 0.01,
        longitude: position.longitude + 0.01,
        address: '123 Main St',
        distance: 1.2,
        isOpen: true,
      ),
      Store(
        id: '2',
        name: 'Trader Joe\'s',
        type: StoreType.grocery,
        latitude: position.latitude - 0.01,
        longitude: position.longitude - 0.01,
        address: '456 Oak Ave',
        distance: 0.8,
        isOpen: true,
      ),
      Store(
        id: '3',
        name: 'Local Farmers Market',
        type: StoreType.farmers_market,
        latitude: position.latitude + 0.005,
        longitude: position.longitude - 0.005,
        address: '789 Market Square',
        distance: 2.5,
        isOpen: false,
      ),
    ];

    return mockStores;
  }

  Future<String> getAddressFromCoordinates(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return 'Unknown location';
  }
}

// ============================================================================
// IMAGE PICKER SERVICE
// ============================================================================
class ImagePickerService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickImageFromCamera() async {
    final hasPermission = await Permission.camera.request().isGranted;
    if (!hasPermission) return null;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    return image?.path;
  }

  Future<String?> pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    return image?.path;
  }
}