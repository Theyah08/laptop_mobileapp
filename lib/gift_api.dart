// To parse this JSON data, do:
//     final item = itemFromJson(jsonString);

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const String giftCatalogUrl =
    'https://gist.githubusercontent.com/Theyah08/172581b884329c75b2a9e9875d2e78b6/raw/75dc8b1b70b70f79efc427db4bc73e0a09334550/gift.json';
const String productsApiUrl =
    'https://6ae43d4d933120ae20f9a3e7.mockapi.io/api/product/product';
const String _catalogStorageKey = 'prosfora_gift_catalog_v1';
const String _catalogMigrationCompleteKey =
    'prosfora_rest_catalog_migration_complete_v1';
int _nextLocalId = 0;

String _newProductId() =>
    'local-${DateTime.now().microsecondsSinceEpoch}-${_nextLocalId++}';

const List<String> giftProductCategories = [
  'Flowers',
  'Mugs and Drinkware',
  'Stationery',
  'Plushies',
  'Fragrance',
];

String normalizeGiftCategory(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(
    RegExp(r'[_-]+'),
    ' ',
  );
  if (normalized.contains('flower')) return 'Flowers';
  if (normalized.contains('mug') || normalized.contains('drinkware')) {
    return 'Mugs and Drinkware';
  }
  if (normalized.contains('station')) return 'Stationery';
  if (normalized.contains('teddy') || normalized.contains('plush')) {
    return 'Plushies';
  }
  if (normalized.contains('perfume') || normalized.contains('fragrance')) {
    return 'Fragrance';
  }
  return 'Other Gifts';
}

const List<String> giftProductImageAssets = [
  'assets/Product/Flowers/1flower_Rose_box.jpg',
  'assets/Product/Flowers/2flower_Dried_bouquet.jpg',
  'assets/Product/Flowers/3flower_Tulip_wrapped.webp',
  'assets/Product/Flowers/4flower_Jar.jpg',
  'assets/Product/Mugs/1mug_Personalized.jpg',
  'assets/Product/Mugs/2mug_minimalist.webp',
  'assets/Product/Mugs/3mug_floral_tea_.webp',
  'assets/Product/Mugs/4mug_Enamel.jpg',
  'assets/Product/Perfume/1perfume_Vanilla.webp',
  'assets/Product/Perfume/2perfume_citrus.jpg',
  'assets/Product/Perfume/3perfume_jasmine.webp',
  'assets/Product/Perfume/4perfume_rollball.jpg',
  'assets/Product/Stationery/1stationery_A5_journal.jpg',
  'assets/Product/Stationery/2stationery_gel_pen.webp',
  'assets/Product/Stationery/3stationery_washitape.webp',
  'assets/Product/Stationery/4stationery_Weekly_planner.jpg',
  'assets/Product/Teddy_bear/1teddy_bear_Brown.jpg',
  'assets/Product/Teddy_bear/2teddy_bear_soft_plush.webp',
  'assets/Product/Teddy_bear/3teddy_bear_keychain.avif',
  'assets/Product/Teddy_bear/4teddy_bear_pastel.jpg',
];

Item itemFromJson(String str) {
  final decoded = json.decode(str);
  if (decoded is List) {
    return Item.fromJsonList(decoded);
  } else if (decoded is Map<String, dynamic>) {
    return Item.fromJson(decoded);
  } else {
    return Item(data: []);
  }
}

String itemToJson(Item data) => json.encode(data.toJson());

class Item {
  Item({required this.data});

  final List<Datum> data;

  // Constructor for parsing top-level JSON arrays [...]
  factory Item.fromJsonList(List<dynamic> list) => Item(
    data: List<Datum>.from(
      list.map((x) => Datum.fromJson(x as Map<String, dynamic>)),
    ),
  );

  // Constructor for parsing object-wrapped JSON {"data": [...]}
  factory Item.fromJson(Map<String, dynamic> json) =>
      Item(data: _parseProducts(json["data"]));

  Map<String, dynamic> toJson() => {
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

List<Datum> _parseProducts(dynamic value) {
  if (value is! List) {
    throw const FormatException('Expected a product list.');
  }
  return value.map((entry) {
    if (entry is! Map<String, dynamic>) {
      throw const FormatException('Product entries must be JSON objects.');
    }
    return Datum.fromJson(entry);
  }).toList();
}

class GiftCatalogStore {
  Future<Item> loadCatalog() async {
    final preferences = await SharedPreferences.getInstance();
    final savedCatalog = preferences.getString(_catalogStorageKey);

    if (savedCatalog != null) {
      try {
        final item = itemFromJson(savedCatalog);
        final uniqueItems = _ensureUniqueIds(item.data);
        final normalizedJson = itemToJson(Item(data: uniqueItems));
        if (normalizedJson != savedCatalog) {
          await _save(preferences, uniqueItems);
        }
        return Item(data: uniqueItems);
      } on FormatException {
        await preferences.remove(_catalogStorageKey);
      } on TypeError {
        await preferences.remove(_catalogStorageKey);
      }
    }

    final response = await http.get(Uri.parse(giftCatalogUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to load products (${response.statusCode}).');
    }

    final item = itemFromJson(response.body);
    final uniqueItems = _ensureUniqueIds(item.data);
    await _save(preferences, uniqueItems);
    return Item(data: uniqueItems);
  }

  Future<void> addProduct(Datum product) async {
    final products = (await loadCatalog()).data;
    products.add(product);
    await _saveCurrent(products);
  }

  Future<void> updateProduct(Datum updatedProduct) async {
    final products = (await loadCatalog()).data;
    final index = products.indexWhere(
      (product) => product.id == updatedProduct.id,
    );
    if (index == -1) {
      throw StateError('The product no longer exists.');
    }
    products[index] = updatedProduct;
    await _saveCurrent(products);
  }

  Future<void> deleteProduct(String id) async {
    final products = (await loadCatalog()).data;
    final originalLength = products.length;
    products.removeWhere((product) => product.id == id);
    if (products.length == originalLength) {
      throw StateError('The product no longer exists.');
    }
    await _saveCurrent(products);
  }

  Future<void> _saveCurrent(List<Datum> products) async {
    final preferences = await SharedPreferences.getInstance();
    await _save(preferences, products);
  }

  Future<void> _save(
    SharedPreferences preferences,
    List<Datum> products,
  ) async {
    await preferences.setString(
      _catalogStorageKey,
      itemToJson(Item(data: products)),
    );
  }

  List<Datum> _ensureUniqueIds(List<Datum> products) {
    final usedIds = <String>{};
    return products.map((product) {
      if (usedIds.add(product.id)) return product;
      var replacementId = _newProductId();
      while (usedIds.contains(replacementId)) {
        replacementId = _newProductId();
      }
      final replacement = product.copyWith(id: replacementId);
      usedIds.add(replacementId);
      return replacement;
    }).toList();
  }
}

class HttpGiftCatalogStore {
  HttpGiftCatalogStore({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _collectionUri => Uri.parse(productsApiUrl);

  Uri _productUri(String id) => _collectionUri.replace(
    pathSegments: [..._collectionUri.pathSegments, id],
  );

  Future<Item> loadCatalog() async {
    final response = await _client.get(_collectionUri);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load products (${response.statusCode}): ${response.body}',
      );
    }
    final catalog = itemFromJson(response.body);
    final preferences = await SharedPreferences.getInstance();

    if (catalog.data.isNotEmpty) {
      await preferences.setBool(_catalogMigrationCompleteKey, true);
      return catalog;
    }
    if (preferences.getBool(_catalogMigrationCompleteKey) ?? false) {
      return catalog;
    }

    final productsToMigrate = await _loadProductsToMigrate(preferences);
    for (final product in productsToMigrate) {
      await createProduct(product);
    }
    await preferences.setBool(_catalogMigrationCompleteKey, true);

    final refreshedResponse = await _client.get(_collectionUri);
    if (refreshedResponse.statusCode != 200) {
      throw Exception(
        'Failed to reload products after migration '
        '(${refreshedResponse.statusCode}): ${refreshedResponse.body}',
      );
    }
    return itemFromJson(refreshedResponse.body);
  }

  Future<List<Datum>> _loadProductsToMigrate(
    SharedPreferences preferences,
  ) async {
    final savedCatalog = preferences.getString(_catalogStorageKey);
    if (savedCatalog != null) {
      try {
        final savedProducts = itemFromJson(savedCatalog).data;
        if (savedProducts.isNotEmpty) return savedProducts;
      } on FormatException {
        await preferences.remove(_catalogStorageKey);
      } on TypeError {
        await preferences.remove(_catalogStorageKey);
      }
    }

    final response = await _client.get(Uri.parse(giftCatalogUrl));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load starter products for migration '
        '(${response.statusCode}): ${response.body}',
      );
    }
    return itemFromJson(response.body).data;
  }

  Future<void> createProduct(Datum product) async {
    final jsonData = product.toJson()..remove('id');
    final response = await _client.post(
      _collectionUri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(jsonData),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to create product (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> updateProduct(Datum product) async {
    final response = await _client.put(
      _productUri(product.id),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(product.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update product (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> deleteProduct(String id) async {
    final response = await _client.delete(_productUri(id));
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'Failed to delete product (${response.statusCode}): ${response.body}',
      );
    }
  }
}

class Datum {
  Datum({
    String? id,
    this.imageAsset,
    this.imagePath,
    required this.itemName,
    required String category,
    required this.pricePhp,
    required this.subtitle,
  }) : id = id ?? _newProductId(),
       category = normalizeGiftCategory(category);

  final String id;
  final String? imageAsset;
  final String? imagePath;
  final String itemName;
  final String category;
  final int pricePhp;
  final String subtitle;

  factory Datum.fromJson(Map<String, dynamic> json) {
    final itemName = (json["item_name"] ?? '').toString();
    final category = (json["category"] ?? '').toString();
    final pricePhp = (json["price_php"] as num?)?.round() ?? 0;
    final subtitle = (json["subtitle"] ?? '').toString();
    return Datum(
      id:
          _productIdFromJson(json["id"]) ??
          'seed-${Uri.encodeComponent('$itemName|$category|$pricePhp|$subtitle')}',
      imageAsset: json["image_asset"] as String?,
      imagePath: json["image_path"] as String?,
      itemName: itemName,
      category: category,
      pricePhp: pricePhp,
      subtitle: subtitle,
    );
  }

  static String? _productIdFromJson(dynamic value) {
    final id = value?.toString().trim();
    return id == null || id.isEmpty ? null : id;
  }

  Datum copyWith({
    String? id,
    String? imageAsset,
    String? imagePath,
    String? itemName,
    String? category,
    int? pricePhp,
    String? subtitle,
  }) => Datum(
    id: id ?? this.id,
    imageAsset: imageAsset ?? this.imageAsset,
    imagePath: imagePath ?? this.imagePath,
    itemName: itemName ?? this.itemName,
    category: category ?? this.category,
    pricePhp: pricePhp ?? this.pricePhp,
    subtitle: subtitle ?? this.subtitle,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    if (imageAsset != null) "image_asset": imageAsset,
    if (imagePath != null) "image_path": imagePath,
    "item_name": itemName,
    "category": category,
    "price_php": pricePhp,
    "subtitle": subtitle,
  };
}

class UserLocalStore {
  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  String _key(String uid, String feature) => 'prosfora_${feature}_$uid';

  Future<Set<String>> loadWishlist(String uid) async =>
      (await _preferences).getStringList(_key(uid, 'wishlist'))?.toSet() ?? {};

  Future<void> saveWishlist(String uid, Set<String> productIds) async {
    await (await _preferences).setStringList(
      _key(uid, 'wishlist'),
      productIds.toList(),
    );
  }

  Future<String> loadPhone(String uid) async =>
      (await _preferences).getString(_key(uid, 'phone')) ?? '';

  Future<void> savePhone(String uid, String phone) async {
    await (await _preferences).setString(_key(uid, 'phone'), phone);
  }

  Future<String?> loadProfilePhoto(String uid) async =>
      (await _preferences).getString(_key(uid, 'profile_photo'));

  Future<void> saveProfilePhoto(String uid, String imagePath) async {
    await (await _preferences).setString(_key(uid, 'profile_photo'), imagePath);
  }

  Future<String> persistImage(
    XFile image, {
    String folder = 'product_photos',
  }) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('The selected image is empty.');
    }

    if (kIsWeb) {
      final extension = path.extension(image.name).toLowerCase();
      final mimeType = switch (extension) {
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.gif' => 'image/gif',
        _ => 'image/jpeg',
      };
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documentsDirectory.path, folder));
    await directory.create(recursive: true);
    final extension = path.extension(image.name).isEmpty
        ? '.jpg'
        : path.extension(image.name);
    final savedPath = path.join(
      directory.path,
      '${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(savedPath).writeAsBytes(bytes, flush: true);
    return savedPath;
  }

  Future<void> resetLocalCatalog() async {
    await (await _preferences).remove(_catalogStorageKey);
  }
}

String? imageAssetForProduct(Datum product) {
  if (product.imagePath?.startsWith('data:image/') == true) return null;
  if (!kIsWeb &&
      product.imagePath != null &&
      File(product.imagePath!).existsSync()) {
    return null;
  }
  if (product.imageAsset != null &&
      giftProductImageAssets.contains(product.imageAsset)) {
    return product.imageAsset;
  }

  final name = product.itemName.toLowerCase();
  final category = product.category.toLowerCase();
  if (name.contains('rose box')) return giftProductImageAssets[0];
  if (name.contains('sunflower') || name.contains('dried bouquet')) {
    return giftProductImageAssets[1];
  }
  if (name.contains('tulip')) return giftProductImageAssets[2];
  if (name.contains('flower jar') || name.contains('dried flower jar')) {
    return giftProductImageAssets[3];
  }
  if (name.contains('personalized') && category.contains('mug')) {
    return giftProductImageAssets[4];
  }
  if ((name.contains('minimalist') || name.contains('tumbler')) &&
      category.contains('mug')) {
    return giftProductImageAssets[5];
  }
  if (name.contains('floral tea')) return giftProductImageAssets[6];
  if (name.contains('enamel') && category.contains('mug')) {
    return giftProductImageAssets[7];
  }
  if (name.contains('vanilla')) return giftProductImageAssets[8];
  if (name.contains('citrus')) return giftProductImageAssets[9];
  if (name.contains('jasmine')) return giftProductImageAssets[10];
  if (name.contains('rollerball') || name.contains('roller ball')) {
    return giftProductImageAssets[11];
  }
  if (name.contains('journal')) return giftProductImageAssets[12];
  if (name.contains('gel pen')) return giftProductImageAssets[13];
  if (name.contains('washi')) return giftProductImageAssets[14];
  if (name.contains('planner')) return giftProductImageAssets[15];
  if (name.contains('brown') && category.contains('teddy')) {
    return giftProductImageAssets[16];
  }
  if (name.contains('giant') || name.contains('soft plush')) {
    return giftProductImageAssets[17];
  }
  if (name.contains('keychain')) return giftProductImageAssets[18];
  if (name.contains('pastel') && category.contains('teddy')) {
    return giftProductImageAssets[19];
  }

  if (category.contains('flower')) return giftProductImageAssets[0];
  if (category.contains('mug')) return giftProductImageAssets[4];
  if (category.contains('perfume')) return giftProductImageAssets[8];
  if (category.contains('station')) return giftProductImageAssets[12];
  if (category.contains('teddy')) return giftProductImageAssets[16];
  return null;
}

Uint8List? imageBytesFromDataUrl(String? dataUrl) {
  if (dataUrl == null || !dataUrl.startsWith('data:image/')) return null;
  final separator = dataUrl.indexOf(',');
  if (separator < 0) return null;
  try {
    return base64Decode(dataUrl.substring(separator + 1));
  } on FormatException {
    return null;
  }
}
