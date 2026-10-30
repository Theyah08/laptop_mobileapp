// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prosforagiftshop/gift_api.dart';
import 'package:prosforagiftshop/login_page.dart';

void main() {
  testWidgets('password can be shown and hidden', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    var passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField.obscureText, isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField.obscureText, isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    passwordField = tester.widget<TextField>(find.byType(TextField).last);
    expect(passwordField.obscureText, isTrue);
  });

  test('legacy product categories normalize to gift shop categories', () {
    expect(normalizeGiftCategory('flower'), 'Flowers');
    expect(normalizeGiftCategory('stationary'), 'Stationery');
    expect(normalizeGiftCategory('teddy_bear'), 'Plushies');
    expect(normalizeGiftCategory('perfume'), 'Fragrance');
    expect(normalizeGiftCategory('mugs'), 'Mugs and Drinkware');
  });

  test('actual catalog product names map to bundled photos', () {
    final flower = Datum(
      itemName: 'Fresh Tulip Wrap',
      category: 'flower',
      pricePhp: 1500,
      subtitle: 'Pure elegance delivered',
    );
    final teddy = Datum(
      itemName: 'Mini Keychain Teddy',
      category: 'teddy bear',
      pricePhp: 150,
      subtitle: 'Cute on the go',
    );

    expect(
      imageAssetForProduct(flower),
      contains('3flower_Tulip_wrapped.webp'),
    );
    expect(imageAssetForProduct(teddy), contains('3teddy_bear_keychain.avif'));
  });

  test('products without remote IDs receive stable IDs from catalog JSON', () {
    const json =
        '[{"item_name":"Test Mug","category":"mugs","price_php":250,"subtitle":"Test"}]';
    final first = itemFromJson(json).data.single;
    final second = itemFromJson(json).data.single;

    expect(first.id, second.id);
    expect(first.category, 'Mugs and Drinkware');
  });

  test('product image path survives catalog save and reload', () async {
    SharedPreferences.setMockInitialValues({
      'prosfora_gift_catalog_v1': '{"data":[]}',
    });
    final catalog = GiftCatalogStore();
    final product = Datum(
      id: 'image-test',
      imagePath: r'C:\app\product_photos\gift.jpg',
      itemName: 'Photo Gift',
      category: 'Flowers',
      pricePhp: 100,
      subtitle: 'A gift with a saved image',
    );

    await catalog.addProduct(product);
    final reloaded = await catalog.loadCatalog();

    expect(reloaded.data.single.imagePath, product.imagePath);
  });

  test('REST catalog uses GET POST PUT and DELETE endpoints', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return switch (request.method) {
        'GET' => http.Response(
          '[{"id":"remote-123","item_name":"Test Gift","category":"Flowers","price_php":100,"subtitle":"Test"}]',
          200,
        ),
        'POST' => http.Response('{"id":"remote-123"}', 201),
        'PUT' => http.Response('{}', 200),
        'DELETE' => http.Response('', 204),
        _ => http.Response('Unsupported method', 405),
      };
    });
    final catalog = HttpGiftCatalogStore(client: client);
    final product = Datum(
      id: 'remote-123',
      itemName: 'Test Gift',
      category: 'Flowers',
      pricePhp: 100,
      subtitle: 'Test',
    );

    final loaded = await catalog.loadCatalog();
    await catalog.createProduct(product);
    await catalog.updateProduct(product);
    await catalog.deleteProduct(product.id);

    expect(loaded.data.single.id, 'remote-123');
    expect(requests.map((request) => request.method), [
      'GET',
      'POST',
      'PUT',
      'DELETE',
    ]);
    expect(requests[0].url.toString(), productsApiUrl);
    expect(requests[1].url.toString(), productsApiUrl);
    expect(requests[1].headers['content-type'], 'application/json');
    expect(jsonDecode(requests[1].body), isNot(contains('id')));
    expect(
      requests[2].url.path,
      '${Uri.parse(productsApiUrl).path}/remote-123',
    );
    expect(requests[3].url.path, requests[2].url.path);
  });

  test(
    'empty REST catalog migrates products saved by the old local store',
    () async {
      SharedPreferences.setMockInitialValues({
        'prosfora_gift_catalog_v1':
            '{"data":[{"id":"local-1","item_name":"Saved Gift","category":"Flowers","price_php":100,"subtitle":"Saved before API migration"}]}',
      });
      final remoteProducts = <Map<String, dynamic>>[];
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode(remoteProducts), 200);
        }
        if (request.method == 'POST') {
          final product = jsonDecode(request.body) as Map<String, dynamic>;
          final createdProduct = {...product, 'id': 'remote-1'};
          remoteProducts.add(createdProduct);
          return http.Response(jsonEncode(createdProduct), 201);
        }
        return http.Response('Unsupported method', 405);
      });

      final catalog = await HttpGiftCatalogStore(client: client).loadCatalog();

      expect(catalog.data.single.id, 'remote-1');
      expect(catalog.data.single.itemName, 'Saved Gift');
      expect(requests.map((request) => request.method), ['GET', 'POST', 'GET']);
      expect(jsonDecode(requests[1].body), isNot(contains('id')));
    },
  );
}
