// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:prosforagiftshop/gift_api.dart';
import 'package:prosforagiftshop/home_page.dart';
import 'package:prosforagiftshop/login_page.dart';
import 'package:prosforagiftshop/orders.dart';
import 'package:prosforagiftshop/profile.dart';
import 'package:prosforagiftshop/shopping_screens.dart';

class _TestUser implements User {
  @override
  String? get displayName => 'Gift Shopper';

  @override
  String? get email => 'shopper@example.com';

  @override
  String? get photoURL => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  testWidgets('profile shows existing account data and shopping shortcuts', (
    WidgetTester tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(
            user: _TestUser(),
            phone: '09123456789',
            address: '12 Gift Lane',
            photoPath: null,
            orderCount: 2,
            orders: const [],
            cartCount: 3,
            wishlistCount: 1,
            rewardPoints: 140,
            onEditProfile: () {},
            onChangePhoto: () {},
            onOpenOrders: () => opened.add('orders'),
            onOpenOrdersByStatus: opened.add,
            onOpenCart: () => opened.add('cart'),
            onOpenWishlist: () => opened.add('wishlist'),
            onOpenRewards: () => opened.add('rewards'),
            onSignOut: () async {},
          ),
        ),
      ),
    );

    expect(find.text('Gift Shopper'), findsAtLeastNWidgets(1));
    expect(find.text('shopper@example.com'), findsAtLeastNWidgets(1));
    expect(find.text('140 pts'), findsOneWidget);
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('2 orders'), findsOneWidget);
    final cartCenter = tester.getCenter(find.text('Cart'));
    final wishlistCenter = tester.getCenter(find.text('Wishlist'));
    final rewardsCenter = tester.getCenter(find.text('Rewards'));
    expect((cartCenter.dy - wishlistCenter.dy).abs(), lessThan(1));
    expect((wishlistCenter.dy - rewardsCenter.dy).abs(), lessThan(1));

    await tester.ensureVisible(find.text('Cart'));
    await tester.tap(find.text('Cart'));
    expect(opened, ['cart']);

    await tester.drag(find.byType(ListView).first, const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    expect(opened, ['cart', 'Completed']);

    await tester.drag(find.byType(ListView).first, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('09123456789'), findsOneWidget);
    expect(find.text('12 Gift Lane'), findsOneWidget);
  });

  testWidgets('settings opens demo order status management', (
    WidgetTester tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            user: _TestUser(),
            onOpenProfile: () {},
            onManageDemoOrderStatuses: () => opened = true,
            onReloadCatalog: () {},
            onSignOut: () async {},
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Demo order statuses'));
    await tester.tap(find.text('Demo order statuses'));
    expect(opened, isTrue);
  });

  testWidgets('demo order status can be changed to cancelled', (
    WidgetTester tester,
  ) async {
    final order = ShopOrder(
      id: 'demo-status-order',
      orderedAt: DateTime(2026, 11, 16),
      shippingAddress: '123 Flower Street',
      lines: const [],
      pointsEarned: 0,
      voucherDiscountPhp: 0,
    );
    String? savedStatus;
    await tester.pumpWidget(
      MaterialApp(
        home: DemoOrderStatusScreen(
          orders: [order],
          onStatusChanged: (order, status) async {
            savedStatus = status;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelled').last);
    await tester.pumpAndSettle();

    expect(savedStatus, 'Cancelled');
    expect(find.text('Cancelled'), findsOneWidget);
  });

  testWidgets('processing order cancellation requires confirmation', (
    WidgetTester tester,
  ) async {
    final order = ShopOrder(
      id: 'processing-order',
      orderedAt: DateTime(2026, 11, 16),
      shippingAddress: '123 Flower Street',
      lines: const [],
      pointsEarned: 0,
      voucherDiscountPhp: 0,
      status: 'Processing',
    );
    var cancelled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrdersScreen(
            orders: [order],
            initialStatus: 'Processing',
            onCancelOrder: (order) async {
              cancelled = true;
              return true;
            },
            onReorderOrder: (order) async => true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget);
    expect(cancelled, isFalse);

    await tester.tap(find.text('Keep Order'));
    await tester.pumpAndSettle();
    expect(cancelled, isFalse);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, Cancel Order'));
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
  });

  testWidgets('completed order can be reordered', (WidgetTester tester) async {
    final order = ShopOrder(
      id: 'completed-order',
      orderedAt: DateTime(2026, 11, 16),
      shippingAddress: '123 Flower Street',
      lines: const [],
      pointsEarned: 0,
      voucherDiscountPhp: 0,
      status: 'Completed',
    );
    var reordered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrdersScreen(
            orders: [order],
            initialStatus: 'Completed',
            onCancelOrder: (order) async => false,
            onReorderOrder: (order) async {
              reordered = true;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Reorder'));
    await tester.pumpAndSettle();
    expect(reordered, isTrue);
    expect(
      find.text('Order #completed-order added to your cart.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'dashboard product cards use cart only and details keep wishlist',
    (WidgetTester tester) async {
      final product = Datum(
        id: 'gift-card-test',
        itemName: 'Fresh Tulip Wrap',
        category: 'Flowers',
        pricePhp: 150,
        subtitle: 'A flower gift',
      );
      final searchController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeDashboard(
              productsFuture: Future.value(Item(data: [product])),
              searchController: searchController,
              searchQuery: '',
              selectedCategory: 'All',
              wishlistCount: 0,
              orderCount: 0,
              rewardPoints: 0,
              onSearchChanged: (_) {},
              onSearchSubmitted: (_) {},
              onSearchAction: () {},
              onCategorySelected: (_) {},
              onReloadProducts: () {},
              onOpenProduct: (_) {},
              onAddToCart: (_) async => true,
              onOpenOrders: () {},
              onOpenWishlist: () {},
              onOpenRewards: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Other Gifts'), findsNothing);
      expect(find.text('A flower gift'), findsNothing);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -900),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add to Wishlist'), findsNothing);
      expect(find.byTooltip('Add to cart'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailsScreen(
            product: product,
            isWishlisted: (_) => false,
            onToggleWishlist: (_) async {},
            onAddToCart: (_, _) async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add to wishlist'), findsOneWidget);
      expect(find.text('A flower gift'), findsOneWidget);
      searchController.dispose();
    },
  );

  testWidgets('search shows matching products without dashboard sections', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    var query = '';
    final products = Item(
      data: [
        Datum(
          id: 'search-notebook',
          itemName: 'A5 Journal',
          category: 'Stationery',
          pricePhp: 250,
          subtitle: 'Lined notebook pages',
        ),
        Datum(
          id: 'search-flowers',
          itemName: 'Rose Bouquet',
          category: 'Flowers',
          pricePhp: 150,
          subtitle: 'A fresh bouquet',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: HomeDashboard(
              productsFuture: Future.value(products),
              searchController: controller,
              searchQuery: query,
              selectedCategory: 'All',
              wishlistCount: 0,
              orderCount: 0,
              rewardPoints: 0,
              onSearchChanged: (value) =>
                  setState(() => query = value.trim().toLowerCase()),
              onSearchSubmitted: (value) =>
                  setState(() => query = value.trim().toLowerCase()),
              onSearchAction: () {},
              onCategorySelected: (_) {},
              onReloadProducts: () {},
              onOpenProduct: (_) {},
              onAddToCart: (_) async => true,
              onOpenOrders: () {},
              onOpenWishlist: () {},
              onOpenRewards: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'notebook');
    await tester.pumpAndSettle();

    expect(find.text('Search results'), findsOneWidget);
    expect(find.text('A5 Journal'), findsOneWidget);
    expect(find.text('Rose Bouquet'), findsNothing);
    expect(find.text('Today Special!'), findsNothing);
    expect(find.text('Orders'), findsNothing);

    controller.dispose();
  });

  test('legacy product categories normalize to gift shop categories', () {
    expect(normalizeGiftCategory('flower'), 'Flowers');
    expect(normalizeGiftCategory('stationary'), 'Stationery');
    expect(normalizeGiftCategory('teddy_bear'), 'Plushies');
    expect(normalizeGiftCategory('perfume'), 'Fragrance');
    expect(normalizeGiftCategory('mugs'), 'Mugs');
  });

  test('profile records include the delivery address', () {
    const profile = UserProfileRecord(
      displayName: 'Gift Shopper',
      email: 'shopper@example.com',
      phone: '09123456789',
      address: '12 Gift Lane',
    );

    expect(UserProfileRecord.fromMap(profile.toMap()).address, '12 Gift Lane');
  });

  test('reward points accrue and redeem at the configured rates', () {
    expect(rewardPointsForPurchase(99), 0);
    expect(rewardPointsForPurchase(100), 1);
    expect(rewardPointsForPurchase(250), 2);

    final redemption = calculateRewardRedemption(
      wallet: const RewardWallet(points: 450),
      subtotalPhp: 1000,
      applyRewards: true,
    );
    expect(redemption.pointsRedeemed, 400);
    expect(redemption.discountPhp, 20);

    final disabled = calculateRewardRedemption(
      wallet: const RewardWallet(points: 450),
      subtotalPhp: 1000,
      applyRewards: false,
    );
    expect(disabled.pointsRedeemed, 0);
    expect(disabled.discountPhp, 0);

    final capped = calculateRewardRedemption(
      wallet: const RewardWallet(points: 600),
      subtotalPhp: 15,
      applyRewards: true,
    );
    expect(capped.pointsRedeemed, 200);
    expect(capped.discountPhp, 10);
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
    expect(first.category, 'Mugs');
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

  test(
    'cart, order, and rewards data persist for the signed-in user',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = UserLocalStore();
      final product = Datum(
        id: 'persisted-gift',
        itemName: 'Rose Bouquet',
        category: 'Flowers',
        pricePhp: 150,
        subtitle: 'A fresh bouquet',
      );
      final order = ShopOrder(
        id: 'order-1',
        orderedAt: DateTime(2026, 11, 16),
        shippingAddress: '123 Flower Street',
        lines: [CartLine(product: product, quantity: 2)],
        pointsEarned: 2,
        voucherDiscountPhp: 50,
      ).copyWith(status: 'Cancelled');

      await store.saveShoppingData(
        'test-user',
        ShoppingData(
          cart: [CartLine(product: product, quantity: 1)],
          orders: [order],
          wallet: const RewardWallet(points: 140, creditPhp: 50),
        ),
      );
      final restored = await store.loadShoppingData('test-user');

      expect(restored.cart.single.totalPhp, 150);
      expect(restored.orders.single.totalPhp, 250);
      expect(restored.orders.single.shippingAddress, '123 Flower Street');
      expect(restored.orders.single.status, 'Cancelled');
      expect(restored.wallet.points, 140);
      expect(restored.wallet.creditPhp, 50);
    },
  );

  testWidgets('cart quantity controls update the subtotal', (
    WidgetTester tester,
  ) async {
    final product = Datum(
      id: 'cart-gift',
      itemName: 'Rose Bouquet',
      category: 'Flowers',
      pricePhp: 150,
      subtitle: 'A fresh bouquet',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CartScreen(
          lines: [CartLine(product: product, quantity: 1)],
          onQuantityChanged: (product, quantity) async => true,
          onRemoveItems: (productIds) async => true,
          onBrowseCatalog: () {},
          onCheckout: (lines) {},
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();

    expect(find.text('₱300'), findsNWidgets(3));
  });

  testWidgets('cart totals include only checked items', (
    WidgetTester tester,
  ) async {
    final firstProduct = Datum(
      id: 'checked-total-gift',
      itemName: 'Rose Bouquet',
      category: 'Flowers',
      pricePhp: 150,
      subtitle: 'A fresh bouquet',
    );
    final secondProduct = Datum(
      id: 'unchecked-total-gift',
      itemName: 'Gift Mug',
      category: 'Mugs',
      pricePhp: 200,
      subtitle: 'A gift mug',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CartScreen(
          lines: [
            CartLine(product: firstProduct, quantity: 1),
            CartLine(product: secondProduct, quantity: 1),
          ],
          onQuantityChanged: (product, quantity) async => true,
          onRemoveItems: (productIds) async => true,
          onBrowseCatalog: () {},
          onCheckout: (lines) {},
        ),
      ),
    );

    expect(find.text('₱0'), findsNWidgets(3));
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(find.text('₱150'), findsNWidgets(3));
    expect(find.text('₱200'), findsOneWidget);
  });

  testWidgets('cart select all toggles and selected items can be deleted', (
    WidgetTester tester,
  ) async {
    final firstProduct = Datum(
      id: 'cart-gift-one',
      itemName: 'Rose Bouquet',
      category: 'Flowers',
      pricePhp: 150,
      subtitle: 'A fresh bouquet',
    );
    final secondProduct = Datum(
      id: 'cart-gift-two',
      itemName: 'Gift Mug',
      category: 'Mugs',
      pricePhp: 200,
      subtitle: 'A gift mug',
    );
    final removedProductIds = <String>{};

    await tester.pumpWidget(
      MaterialApp(
        home: CartScreen(
          lines: [
            CartLine(product: firstProduct, quantity: 1),
            CartLine(product: secondProduct, quantity: 1),
          ],
          onQuantityChanged: (product, quantity) async => true,
          onRemoveItems: (productIds) async {
            removedProductIds.addAll(productIds);
            return true;
          },
          onBrowseCatalog: () {},
          onCheckout: (lines) {},
        ),
      ),
    );

    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((checkbox) => checkbox.value == true),
      isTrue,
    );

    await tester.tap(find.text('Deselect all'));
    await tester.pump();
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .every((checkbox) => checkbox.value == false),
      isTrue,
    );

    await tester.tap(find.text('Select all'));
    await tester.pump();
    await tester.tap(find.text('Delete selected (2)'));
    await tester.pumpAndSettle();

    expect(removedProductIds, {'cart-gift-one', 'cart-gift-two'});
    expect(find.text('Your cart is empty.'), findsOneWidget);
  });

  testWidgets('cart checkout receives only checked items', (
    WidgetTester tester,
  ) async {
    final firstProduct = Datum(
      id: 'checked-gift',
      itemName: 'Rose Bouquet',
      category: 'Flowers',
      pricePhp: 150,
      subtitle: 'A fresh bouquet',
    );
    final secondProduct = Datum(
      id: 'unchecked-gift',
      itemName: 'Gift Mug',
      category: 'Mugs',
      pricePhp: 200,
      subtitle: 'A gift mug',
    );
    List<CartLine>? checkedOutLines;

    await tester.pumpWidget(
      MaterialApp(
        home: CartScreen(
          lines: [
            CartLine(product: firstProduct, quantity: 1),
            CartLine(product: secondProduct, quantity: 1),
          ],
          onQuantityChanged: (product, quantity) async => true,
          onRemoveItems: (productIds) async => true,
          onBrowseCatalog: () {},
          onCheckout: (lines) => checkedOutLines = lines,
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.text('Proceed to Checkout (1)'));

    expect(checkedOutLines, hasLength(1));
    expect(checkedOutLines!.single.product.id, 'checked-gift');
  });

  testWidgets('empty cart browse button returns to the dashboard', (
    WidgetTester tester,
  ) async {
    var dashboardRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: CartScreen(
          lines: const [],
          onQuantityChanged: (product, quantity) async => true,
          onRemoveItems: (productIds) async => true,
          onBrowseCatalog: () => dashboardRequested = true,
          onCheckout: (lines) {},
        ),
      ),
    );

    await tester.tap(find.text('Browse gifts'));
    expect(dashboardRequested, isTrue);
  });

  testWidgets('checkout requires an address before placing a demo order', (
    WidgetTester tester,
  ) async {
    final product = Datum(
      id: 'checkout-gift',
      itemName: 'Rose Bouquet',
      category: 'Flowers',
      pricePhp: 150,
      subtitle: 'A fresh bouquet',
    );
    final order = ShopOrder(
      id: 'order-2',
      orderedAt: DateTime(2026, 11, 16),
      shippingAddress: '123 Flower Street',
      lines: [CartLine(product: product, quantity: 1)],
      pointsEarned: 1,
      voucherDiscountPhp: 0,
    );
    var placed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutScreen(
          lines: [CartLine(product: product, quantity: 1)],
          wallet: const RewardWallet(),
          initialAddress: '',
          onPlaceOrder: (address, applyRewards) async {
            expect(applyRewards, isFalse);
            placed = true;
            expect(address, '123 Flower Street');
            return order;
          },
          onViewOrders: () {},
          onContinueShopping: () {},
        ),
      ),
    );

    await tester.tap(find.textContaining('Confirm Checkout'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a delivery address'), findsOneWidget);
    expect(placed, isFalse);

    await tester.enterText(find.byType(TextFormField), '123 Flower Street');
    await tester.tap(find.textContaining('Confirm Checkout'));
    await tester.pumpAndSettle();

    expect(placed, isTrue);
    expect(find.text('Order Placed!'), findsOneWidget);
  });

  testWidgets('checkout applies rewards only after the toggle is enabled', (
    WidgetTester tester,
  ) async {
    final product = Datum(
      id: 'rewards-checkout-gift',
      itemName: 'Rose Bouquet',
      category: 'Flowers',
      pricePhp: 150,
      subtitle: 'A fresh bouquet',
    );
    var rewardsApplied = false;

    await tester.pumpWidget(
      MaterialApp(
        home: CheckoutScreen(
          lines: [CartLine(product: product, quantity: 1)],
          wallet: const RewardWallet(points: 400),
          initialAddress: '123 Flower Street',
          onPlaceOrder: (address, applyRewards) async {
            rewardsApplied = applyRewards;
            return ShopOrder(
              id: 'rewards-order',
              orderedAt: DateTime(2026, 11, 16),
              shippingAddress: address,
              lines: [CartLine(product: product, quantity: 1)],
              pointsEarned: 1,
              voucherDiscountPhp: applyRewards ? 20 : 0,
            );
          },
          onViewOrders: () {},
          onContinueShopping: () {},
        ),
      ),
    );

    expect(find.textContaining('Confirm Checkout · ₱150'), findsOneWidget);
    await tester.tap(find.text('Apply rewards'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confirm Checkout · ₱130'), findsOneWidget);
    expect(find.text('Rewards discount'), findsOneWidget);

    await tester.tap(find.textContaining('Confirm Checkout'));
    await tester.pumpAndSettle();

    expect(rewardsApplied, isTrue);
    expect(find.text('Order Placed!'), findsOneWidget);
    expect(find.text('Order #rewards-order · ₱130'), findsOneWidget);
  });
}
