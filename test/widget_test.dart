// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    final keychain = Datum(
      itemName: 'Mini Keychain Teddy',
      category: 'teddy bear',
      pricePhp: 150,
      subtitle: 'Cute on the go',
    );
    final brownPlush = Datum(
      itemName: 'Classic Brown Cuddle Bear',
      category: 'Plushies',
      pricePhp: 599,
      subtitle: 'Soft hugging buddy',
    );
    final pastelPlush = Datum(
      itemName: 'Pastel Pink Bow Bear',
      category: 'Plushies',
      pricePhp: 680,
      subtitle: 'Sweet companion gift',
    );

    expect(
      imageAssetForProduct(flower),
      contains('3flower_Tulip_wrapped.webp'),
    );
    expect(
      imageAssetForProduct(keychain),
      contains('3teddy_bear_keychain.jpg'),
    );
    expect(imageAssetForProduct(brownPlush), contains('1teddy_bear_Brown.jpg'));
    expect(
      imageAssetForProduct(pastelPlush),
      contains('4teddy_bear_pastel.jpg'),
    );
  });

  test('product image assets are bundled', () async {
    for (final asset in giftProductImageAssets) {
      await rootBundle.load(asset);
    }
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
}
