import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prosforagiftshop/main_page.dart';
import 'package:prosforagiftshop/gift_api.dart';
import 'package:prosforagiftshop/item_catalog_screen.dart';
import 'package:prosforagiftshop/product.dart';
import 'package:prosforagiftshop/orders.dart';
import 'package:prosforagiftshop/profile.dart';
import 'package:prosforagiftshop/shopping_screens.dart';

class ExampleDestination {
  const ExampleDestination(this.label, this.icon, this.selectedIcon);

  final String label;
  final Widget icon;
  final Widget selectedIcon;
}

const List<ExampleDestination> destinations = <ExampleDestination>[
  ExampleDestination(
    'Dashboard',
    Icon(Icons.store_outlined),
    Icon(Icons.store),
  ),
  ExampleDestination(
    'Orders',
    Icon(Icons.shopping_bag_outlined),
    Icon(Icons.shopping_bag),
  ),
  ExampleDestination(
    'Settings',
    Icon(Icons.settings_outlined),
    Icon(Icons.settings),
  ),
];

const List<ExampleDestination> wideDestinations = <ExampleDestination>[
  ...destinations,
  ExampleDestination(
    'Wishlist',
    Icon(Icons.favorite_border),
    Icon(Icons.favorite),
  ),
  ExampleDestination('Profile', Icon(Icons.person_outline), Icon(Icons.person)),
  ExampleDestination('Rewards', Icon(Icons.stars_outlined), Icon(Icons.stars)),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController searchController = TextEditingController();
  final CatalogApi catalogStore = FirestoreGiftCatalogStore();
  final UserLocalStore userStore = UserLocalStore();
  final FirestoreUserProfileStore profileStore = FirestoreUserProfileStore();

  int screenIndex = 0;
  String initialOrdersStatus = 'All';
  late bool showNavigationDrawer;
  String selectedCategory = 'All';
  String searchQuery = '';
  late Future<Item> productsFuture;
  Set<String> wishlistIds = {};
  List<CartLine> cartItems = [];
  List<ShopOrder> orderHistory = [];
  RewardWallet rewardWallet = const RewardWallet();
  String profilePhone = '';
  String profileAddress = '';
  String? profilePhotoPath;
  bool userDataLoading = true;
  bool productOperationInProgress = false;

  @override
  void initState() {
    super.initState();
    productsFuture = catalogStore.loadCatalog();
    _loadUserData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = _currentUserId;
    if (uid == null) {
      if (mounted) setState(() => userDataLoading = false);
      return;
    }
    try {
      final values = await Future.wait([
        userStore.loadWishlist(uid),
        userStore.loadPhone(uid),
        userStore.loadProfilePhoto(uid),
        userStore.loadShoppingData(uid),
      ]);
      if (!mounted) return;
      final shoppingData = values[3] as ShoppingData;
      final recentAddress = shoppingData.orders
          .map((order) => order.shippingAddress)
          .firstWhere((address) => address.isNotEmpty, orElse: () => '');
      UserProfileRecord? savedProfile;
      try {
        savedProfile = await profileStore.load(uid);
        if (savedProfile == null) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            savedProfile = UserProfileRecord(
              displayName: currentUser.displayName ?? '',
              email: currentUser.email ?? '',
              phone: values[1] as String,
              address: recentAddress,
            );
            await profileStore.save(uid, savedProfile);
          }
        }
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile data could not be synced: $error')),
        );
      }
      if (!mounted) return;
      setState(() {
        wishlistIds = values[0] as Set<String>;
        profilePhone = savedProfile?.phone.isNotEmpty == true
            ? savedProfile!.phone
            : values[1] as String;
        profileAddress = savedProfile?.address.isNotEmpty == true
            ? savedProfile!.address
            : recentAddress;
        profilePhotoPath = values[2] as String?;
        cartItems = shoppingData.cart;
        orderHistory = shoppingData.orders;
        rewardWallet = shoppingData.wallet;
        userDataLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => userDataLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved account data could not be loaded: $error'),
        ),
      );
    }
  }

  void _selectScreen(int selectedScreen) {
    setState(() {
      screenIndex = selectedScreen;
      if (selectedScreen == 1) initialOrdersStatus = 'All';
    });
  }

  void _handleScreenChanged(int selectedScreen) {
    _selectScreen(selectedScreen);
  }

  void _openOrdersByStatus(String status) {
    setState(() {
      screenIndex = 1;
      initialOrdersStatus = status;
    });
  }

  void _handleFooterChanged(int selectedIndex) {
    switch (selectedIndex) {
      case 0:
        _selectScreen(0);
      case 1:
        _selectScreen(4);
      case 2:
        _openCart();
    }
  }

  Future<Item> _reloadProducts() {
    final future = catalogStore.loadCatalog();
    setState(() {
      productsFuture = future;
    });
    return future;
  }

  ShoppingData get _shoppingData =>
      ShoppingData(cart: cartItems, orders: orderHistory, wallet: rewardWallet);

  Future<void> _saveShoppingData(ShoppingData data) async {
    final uid = _currentUserId;
    if (uid == null) throw StateError('Sign in to save shopping data.');
    await userStore.saveShoppingData(uid, data);
  }

  Future<bool> _addToCart(Datum product, int quantity) async {
    final previous = cartItems;
    final updated = [...cartItems];
    final index = updated.indexWhere((line) => line.product.id == product.id);
    if (index < 0) {
      updated.add(CartLine(product: product, quantity: quantity));
    } else {
      updated[index] = updated[index].copyWith(
        product: product,
        quantity: updated[index].quantity + quantity,
      );
    }
    setState(() => cartItems = updated);
    try {
      await _saveShoppingData(_shoppingData);
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => cartItems = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cart could not be saved: $error')),
        );
      }
      return false;
    }
  }

  Future<bool> _changeCartQuantity(Datum product, int quantity) async {
    final previous = cartItems;
    final updated = [...cartItems];
    final index = updated.indexWhere((line) => line.product.id == product.id);
    if (index < 0) return false;
    if (quantity < 1) {
      updated.removeAt(index);
    } else {
      updated[index] = updated[index].copyWith(quantity: quantity);
    }
    setState(() => cartItems = updated);
    try {
      await _saveShoppingData(_shoppingData);
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => cartItems = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cart could not be saved: $error')),
      );
      return false;
    }
  }

  Future<bool> _removeCartItems(Set<String> productIds) async {
    final previous = cartItems;
    final updated = cartItems
        .where((line) => !productIds.contains(line.product.id))
        .toList();
    if (updated.length == previous.length) return true;
    setState(() => cartItems = updated);
    try {
      await _saveShoppingData(_shoppingData);
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => cartItems = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected cart items could not be removed: $error'),
        ),
      );
      return false;
    }
  }

  Future<ShopOrder> _placeOrder(
    List<CartLine> checkoutLines,
    String address,
    bool applyRewards,
  ) async {
    if (checkoutLines.isEmpty) {
      throw StateError('Select at least one item to check out.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before placing an order.');
    try {
      await profileStore.save(
        user.uid,
        UserProfileRecord(
          displayName: user.displayName ?? '',
          email: user.email ?? '',
          phone: profilePhone,
          address: address,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile address could not be synced: $error'),
          ),
        );
      }
    }
    if (mounted) setState(() => profileAddress = address);
    final subtotal = checkoutLines.fold(
      0,
      (total, line) => total + line.totalPhp,
    );
    final redemption = calculateRewardRedemption(
      wallet: rewardWallet,
      subtotalPhp: subtotal,
      applyRewards: applyRewards,
    );
    final order = ShopOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderedAt: DateTime.now(),
      shippingAddress: address,
      lines: List<CartLine>.unmodifiable(checkoutLines),
      pointsEarned: rewardPointsForPurchase(subtotal),
      voucherDiscountPhp: redemption.discountPhp,
    );
    final updatedOrders = [order, ...orderHistory];
    final updatedWallet = rewardWallet.copyWith(
      points:
          rewardWallet.points - redemption.pointsRedeemed + order.pointsEarned,
      creditPhp: rewardWallet.creditPhp - redemption.creditUsedPhp,
    );
    final checkedProductIds = checkoutLines
        .map((line) => line.product.id)
        .toSet();
    final remainingCart = cartItems
        .where((line) => !checkedProductIds.contains(line.product.id))
        .toList();
    await _saveShoppingData(
      ShoppingData(
        cart: remainingCart,
        orders: updatedOrders,
        wallet: updatedWallet,
      ),
    );
    if (mounted) {
      setState(() {
        cartItems = remainingCart;
        orderHistory = updatedOrders;
        rewardWallet = updatedWallet;
      });
    }
    return order;
  }

  Future<void> _redeemReward() async {
    if (rewardWallet.points < 200) return;
    final updatedWallet = rewardWallet.copyWith(
      points: rewardWallet.points - 200,
      creditPhp: rewardWallet.creditPhp + 10,
    );
    try {
      await _saveShoppingData(
        ShoppingData(
          cart: cartItems,
          orders: orderHistory,
          wallet: updatedWallet,
        ),
      );
      if (!mounted) return;
      setState(() => rewardWallet = updatedWallet);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('₱10 reward credit added.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reward could not be redeemed: $error')),
      );
    }
  }

  void _openItemCatalog() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ItemCatalogScreen(
          productsFuture: productsFuture,
          loadProducts: _reloadProducts,
          onAddProduct: () => _editProduct(),
          onEditProduct: (item) => _editProduct(product: item),
          onDeleteProduct: _deleteProduct,
          onOpenProduct: _showProductDetails,
          isWishlisted: _isWishlisted,
          onToggleWishlist: _toggleWishlist,
        ),
      ),
    );
  }

  Future<void> _editProduct({Datum? product}) async {
    if (productOperationInProgress) return;
    final result = await showDialog<Datum>(
      context: context,
      builder: (context) =>
          ProductEditorDialog(product: product, userStore: userStore),
    );
    if (result == null || !mounted) return;
    productOperationInProgress = true;
    try {
      if (product == null) {
        await catalogStore.createProduct(result);
      } else {
        await catalogStore.updateProduct(result);
      }
      await _reloadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product == null ? 'Product added.' : 'Product updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save product: $error')));
    } finally {
      productOperationInProgress = false;
    }
  }

  Future<void> _deleteProduct(Datum product) async {
    if (productOperationInProgress) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove "${product.itemName}" from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    productOperationInProgress = true;
    try {
      await catalogStore.deleteProduct(product.id);
      wishlistIds.remove(product.id);
      final uid = _currentUserId;
      if (uid != null) await userStore.saveWishlist(uid, wishlistIds);
      await _reloadProducts();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Product deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete product: $error')),
      );
    } finally {
      productOperationInProgress = false;
    }
  }

  bool _isWishlisted(Datum product) => wishlistIds.contains(product.id);

  Future<void> _toggleWishlist(Datum product) async {
    final uid = _currentUserId;
    if (uid == null) return;
    final wasSaved = wishlistIds.contains(product.id);
    setState(() {
      if (wasSaved) {
        wishlistIds.remove(product.id);
      } else {
        wishlistIds.add(product.id);
      }
    });
    try {
      await userStore.saveWishlist(uid, wishlistIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasSaved ? 'Removed from Wishlist.' : 'Added to Wishlist.',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          wishlistIds.add(product.id);
        } else {
          wishlistIds.remove(product.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wishlist could not be saved: $error')),
      );
    }
  }

  void _showProductDetails(Datum product) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ProductDetailsScreen(
          product: product,
          isWishlisted: _isWishlisted,
          onToggleWishlist: _toggleWishlist,
          onAddToCart: _addToCart,
        ),
      ),
    );
  }

  void _openCart() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => CartScreen(
          lines: cartItems,
          onQuantityChanged: _changeCartQuantity,
          onRemoveItems: _removeCartItems,
          onBrowseCatalog: _returnToHome,
          onCheckout: _openCheckout,
        ),
      ),
    );
  }

  void _openDemoOrderStatuses() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => DemoOrderStatusScreen(
          orders: orderHistory,
          onStatusChanged: _updateDemoOrderStatus,
        ),
      ),
    );
  }

  Future<bool> _updateDemoOrderStatus(ShopOrder order, String status) async {
    final updatedOrders = orderHistory
        .map(
          (current) => current.id == order.id
              ? current.copyWith(status: status)
              : current,
        )
        .toList();
    try {
      await _saveShoppingData(
        ShoppingData(
          cart: cartItems,
          orders: updatedOrders,
          wallet: rewardWallet,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status could not be saved: $error')),
        );
      }
      return false;
    }

    if (!mounted) return false;
    setState(() => orderHistory = updatedOrders);
    return true;
  }

  Future<bool> _cancelOrder(ShopOrder order) {
    if (order.status != 'Processing') return Future.value(false);
    return _updateDemoOrderStatus(order, 'Cancelled');
  }

  Future<bool> _reorderOrder(ShopOrder order) async {
    if (order.status != 'Completed') return false;
    if (order.lines.isEmpty) return false;

    final previousCart = cartItems;
    final updatedCart = [...cartItems];
    for (final line in order.lines) {
      final index = updatedCart.indexWhere(
        (existing) => existing.product.id == line.product.id,
      );
      if (index < 0) {
        updatedCart.add(line);
      } else {
        updatedCart[index] = updatedCart[index].copyWith(
          product: line.product,
          quantity: updatedCart[index].quantity + line.quantity,
        );
      }
    }

    setState(() => cartItems = updatedCart);
    try {
      await _saveShoppingData(
        ShoppingData(
          cart: updatedCart,
          orders: orderHistory,
          wallet: rewardWallet,
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => cartItems = previousCart);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order could not be reordered: $error')),
      );
      return false;
    }
  }

  void _openCheckout(List<CartLine> checkoutLines) {
    if (checkoutLines.isEmpty) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (context) => CheckoutScreen(
          lines: List<CartLine>.unmodifiable(checkoutLines),
          wallet: rewardWallet,
          initialAddress: profileAddress,
          onPlaceOrder: (address, applyRewards) =>
              _placeOrder(checkoutLines, address, applyRewards),
          onViewOrders: _returnToOrders,
          onContinueShopping: _returnToHome,
        ),
      ),
    );
  }

  void _returnToOrders() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (mounted) setState(() => screenIndex = 1);
  }

  void _returnToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (mounted) setState(() => screenIndex = 0);
  }

  Future<void> _editProfile(User user) async {
    final result = await showProfileEditDialog(
      context: context,
      user: user,
      phone: profilePhone,
      address: profileAddress,
      onSave: (name, phone, address) async {
        final current = FirebaseAuth.instance.currentUser;
        if (current == null) {
          throw StateError('Sign in before saving profile changes.');
        }
        await current.updateDisplayName(name);
        await current.reload();
        await profileStore.save(
          current.uid,
          UserProfileRecord(
            displayName: name,
            email: current.email ?? user.email ?? '',
            phone: phone,
            address: address,
          ),
        );
        await userStore.savePhone(current.uid, phone);
      },
    );
    if (result != null && mounted) {
      setState(() {
        profilePhone = result.phone;
        profileAddress = result.address;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    }
  }

  Future<void> _changeProfilePhoto(User user) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;
    try {
      final savedPath = await userStore.persistImage(
        image,
        folder: 'profile_photos',
      );
      await userStore.saveProfilePhoto(user.uid, savedPath);
      if (!mounted) return;
      setState(() => profilePhotoPath = savedPath);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile photo could not be saved: $error')),
      );
    }
  }

  Future<void> _signOut() => FirebaseAuth.instance.signOut();

  Future<void> _confirmReloadCatalog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reload product catalog?'),
        content: const Text(
          'This reloads products from the catalog service. It will not delete products stored in Firebase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reload'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final refreshed = await catalogStore.loadCatalog();
      if (!mounted) return;
      setState(() {
        productsFuture = Future.value(refreshed);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Catalog could not be reloaded: $error')),
      );
    }
  }

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Widget _buildSelectedScreen(User? user) {
    switch (screenIndex) {
      case 1:
        return OrdersScreen(
          orders: orderHistory,
          initialStatus: initialOrdersStatus,
          onCancelOrder: _cancelOrder,
          onReorderOrder: _reorderOrder,
        );
      case 2:
        return SettingsScreen(
          user: user,
          onOpenProfile: () => _selectScreen(4),
          onManageDemoOrderStatuses: _openDemoOrderStatuses,
          onReloadCatalog: _confirmReloadCatalog,
          onSignOut: _signOut,
        );
      case 3:
        return WishlistScreen(
          userDataLoading: userDataLoading,
          productsFuture: productsFuture,
          wishlistIds: wishlistIds,
          onOpenProduct: _showProductDetails,
          onToggleWishlist: _toggleWishlist,
        );
      case 4:
        return ProfileScreen(
          user: user,
          phone: profilePhone,
          address: profileAddress,
          photoPath: profilePhotoPath,
          orderCount: orderHistory.length,
          orders: orderHistory,
          cartCount: cartItems.fold(0, (total, line) => total + line.quantity),
          wishlistCount: wishlistIds.length,
          rewardPoints: rewardWallet.points,
          onEditProfile: user == null ? () {} : () => _editProfile(user),
          onChangePhoto: user == null ? () {} : () => _changeProfilePhoto(user),
          onOpenOrders: () => _selectScreen(1),
          onOpenOrdersByStatus: _openOrdersByStatus,
          onOpenCart: _openCart,
          onOpenWishlist: () => _selectScreen(3),
          onOpenRewards: () => _selectScreen(5),
          onSignOut: _signOut,
        );
      case 5:
        return RewardsScreen(
          wallet: rewardWallet,
          orders: orderHistory,
          onRedeem: _redeemReward,
        );
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() => HomeDashboard(
    productsFuture: productsFuture,
    searchController: searchController,
    searchQuery: searchQuery,
    selectedCategory: selectedCategory,
    wishlistCount: wishlistIds.length,
    orderCount: orderHistory.length,
    rewardPoints: rewardWallet.points,
    onSearchChanged: (value) =>
        setState(() => searchQuery = value.trim().toLowerCase()),
    onSearchSubmitted: (value) =>
        setState(() => searchQuery = value.trim().toLowerCase()),
    onSearchAction: () {
      if (searchQuery.isEmpty) {
        setState(
          () => searchQuery = searchController.text.trim().toLowerCase(),
        );
        FocusScope.of(context).unfocus();
      } else {
        searchController.clear();
        setState(() => searchQuery = '');
      }
    },
    onCategorySelected: (category) =>
        setState(() => selectedCategory = category),
    onReloadProducts: _reloadProducts,
    onOpenProduct: _showProductDetails,
    onAddToCart: (product) async {
      final added = await _addToCart(product, 1);
      if (added && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${product.itemName} added to cart.')),
        );
      }
      return added;
    },
    onOpenOrders: () => _selectScreen(1),
    onOpenWishlist: () => _selectScreen(3),
    onOpenRewards: () => _selectScreen(5),
  );

  List<Widget> _buildAppBarActions() => [
    IconButton(
      tooltip: 'Browse item categories',
      onPressed: _openItemCatalog,
      icon: const Icon(Icons.category_outlined),
    ),
  ];

  Widget _buildBottomBarScaffold(User? user) => Scaffold(
    key: scaffoldKey,
    appBar: AppBar(
      title: const Text(
        'Prosfora Gift Shop',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      backgroundColor: GiftShopColors.mauvelous,
      foregroundColor: GiftShopColors.ink,
      actions: _buildAppBarActions(),
    ),
    drawer: _buildNavigationDrawer(user),
    body: _buildSelectedScreen(user),
    bottomNavigationBar: Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GiftShopColors.ink,
        borderRadius: BorderRadius.circular(30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BottomNavigationBar(
          currentIndex: screenIndex == 4 ? 1 : 0,
          onTap: _handleFooterChanged,
          backgroundColor: Colors.transparent,
          selectedItemColor: GiftShopColors.mauvelous,
          unselectedItemColor: GiftShopColors.lilacFizz,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.store_outlined),
              activeIcon: Icon(Icons.store),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              activeIcon: Icon(Icons.shopping_cart),
              label: 'Cart',
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildNavigationDrawer(User? user) {
    final avatarImage = profileImageProvider(profilePhotoPath, user?.photoURL);
    const drawerRowPadding = EdgeInsets.only(left: 30, right: 16);
    return NavigationDrawerTheme(
      data: const NavigationDrawerThemeData(tileHeight: 48),
      child: NavigationDrawer(
        selectedIndex: switch (screenIndex) {
          0 => 0,
          4 => 1,
          1 => 2,
          _ => null,
        },
        tilePadding: const EdgeInsets.only(left: 24, right: 12),
        onDestinationSelected: (index) {
          final selectedScreen = switch (index) {
            0 => 0,
            1 => 4,
            2 => 1,
            _ => screenIndex,
          };
          _handleScreenChanged(selectedScreen);
          Navigator.pop(context);
        },
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: GiftShopColors.cottonCandy,
              border: Border(
                bottom: BorderSide(color: GiftShopColors.ink.withAlpha(100)),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? const Icon(
                          Icons.card_giftcard,
                          color: GiftShopColors.mauvelous,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName?.isNotEmpty == true
                            ? user!.displayName!
                            : 'Prosfora Customer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GiftShopColors.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'No email',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: GiftShopColors.mutedInk),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const NavigationDrawerDestination(
            label: Text('Dashboard'),
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store),
          ),
          const NavigationDrawerDestination(
            label: Text('My Profile'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
          ),
          const NavigationDrawerDestination(
            label: Text('Orders'),
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
          ),
          const Divider(height: 8),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Wishlist'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            contentPadding: drawerRowPadding,
            minTileHeight: 48,
            onTap: () {
              Navigator.pop(context);
              _selectScreen(3);
            },
          ),
          ListTile(
            leading: const Icon(Icons.stars_outlined),
            title: const Text('Rewards'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            contentPadding: drawerRowPadding,
            minTileHeight: 48,
            onTap: () {
              Navigator.pop(context);
              _selectScreen(5);
            },
          ),
          ListTile(
            leading: const Icon(Icons.view_list_outlined),
            title: const Text('Item Catalog'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            contentPadding: drawerRowPadding,
            minTileHeight: 48,
            onTap: () {
              Navigator.pop(context);
              _openItemCatalog();
            },
          ),
          ListTile(
            leading: Icon(
              screenIndex == 2 ? Icons.settings : Icons.settings_outlined,
            ),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right, size: 20),
            contentPadding: drawerRowPadding,
            minTileHeight: 48,
            selected: screenIndex == 2,
            selectedTileColor: GiftShopColors.denim,
            selectedColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            onTap: () {
              Navigator.pop(context);
              _selectScreen(2);
            },
          ),
          const Divider(height: 8),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await _signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerScaffold(User? user) => Scaffold(
    key: scaffoldKey,
    appBar: AppBar(
      title: const Text(
        'Prosfora Gift Shop',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      backgroundColor: GiftShopColors.mauvelous,
      foregroundColor: GiftShopColors.ink,
      actions: _buildAppBarActions(),
    ),
    body: SafeArea(
      child: Row(
        children: [
          NavigationRail(
            minWidth: 60,
            destinations: wideDestinations
                .map(
                  (destination) => NavigationRailDestination(
                    label: Text(destination.label),
                    icon: destination.icon,
                    selectedIcon: destination.selectedIcon,
                  ),
                )
                .toList(),
            selectedIndex: screenIndex.clamp(0, wideDestinations.length - 1),
            useIndicator: true,
            onDestinationSelected: _handleScreenChanged,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildSelectedScreen(user)),
        ],
      ),
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    showNavigationDrawer = MediaQuery.widthOf(context) >= 450;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return showNavigationDrawer
        ? _buildDrawerScaffold(user)
        : _buildBottomBarScaffold(user);
  }
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.productsFuture,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.wishlistCount,
    required this.orderCount,
    required this.rewardPoints,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchAction,
    required this.onCategorySelected,
    required this.onReloadProducts,
    required this.onOpenProduct,
    required this.onAddToCart,
    required this.onOpenOrders,
    required this.onOpenWishlist,
    required this.onOpenRewards,
  });

  final Future<Item> productsFuture;
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedCategory;
  final int wishlistCount;
  final int orderCount;
  final int rewardPoints;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onSearchAction;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onReloadProducts;
  final ValueChanged<Datum> onOpenProduct;
  final Future<bool> Function(Datum) onAddToCart;
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenWishlist;
  final VoidCallback onOpenRewards;

  static const List<Map<String, Object>> _categories = [
    {'name': 'Flowers', 'icon': Icons.local_florist},
    {'name': 'Mugs', 'icon': Icons.coffee},
    {'name': 'Stationery', 'icon': Icons.edit_note},
    {'name': 'Plushies', 'icon': Icons.smart_toy_outlined},
    {'name': 'Fragrance', 'icon': Icons.science},
  ];

  List<String> get _filterChips => ['All', ...giftProductCategories];

  IconData _categoryIcon(String category) {
    switch (normalizeGiftCategory(category)) {
      case 'Mugs':
        return Icons.coffee;
      case 'Flowers':
        return Icons.local_florist;
      case 'Stationery':
        return Icons.edit_note;
      case 'Plushies':
        return Icons.smart_toy_outlined;
      case 'Fragrance':
        return Icons.science;
      default:
        return Icons.card_giftcard;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = GiftShopColors.mauvelous;
    const accentPink = GiftShopColors.mauvelous;
    final isSearching = searchQuery.trim().isNotEmpty;
    return ColoredBox(
      color: GiftShopColors.canvas,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          textInputAction: TextInputAction.search,
                          onChanged: onSearchChanged,
                          onSubmitted: onSearchSubmitted,
                          decoration: const InputDecoration(
                            hintText: 'Search for flowers, gifts...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: searchQuery.isEmpty
                            ? 'Search products'
                            : 'Clear search',
                        onPressed: onSearchAction,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: accentPink,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            searchQuery.isEmpty ? Icons.search : Icons.close,
                            color: GiftShopColors.ink,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSearching) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Search results',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (!isSearching) ...[
                  const SizedBox(height: 16),
                  Container(
                    height: 176,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/Product/Flowers/1flower_Rose_box.jpg',
                            fit: BoxFit.cover,
                            alignment: Alignment.centerRight,
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xE6000000), Color(0x00000000)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [0, 1],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: 230,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Today Special!',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Get 15% OFF',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Text(
                                    'Romantic Flowers',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  FilledButton(
                                    onPressed: () =>
                                        onCategorySelected('Flowers'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: accentPink,
                                      foregroundColor: GiftShopColors.ink,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                    ),
                                    child: const Text('Browse flowers'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) => SizedBox(
                      height: 75,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              for (final item in _categories)
                                _categoryItem(
                                  item,
                                  onCategorySelected,
                                  selectedCategory,
                                  primaryColor,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          'Orders',
                          '$orderCount Orders',
                          Icons.receipt_long_outlined,
                          GiftShopColors.denim,
                          onTap: onOpenOrders,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          'Wishlist',
                          '$wishlistCount Items',
                          Icons.favorite_border,
                          GiftShopColors.mauvelous,
                          onTap: onOpenWishlist,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _statCard(
                          'Rewards',
                          '$rewardPoints Points',
                          Icons.stars_outlined,
                          GiftShopColors.lilacFizz,
                          onTap: onOpenRewards,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filterChips.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final chip = _filterChips[index];
                        final isSelected = selectedCategory == chip;
                        return ChoiceChip(
                          label: Text(
                            chip,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? GiftShopColors.ink
                                  : GiftShopColors.mutedInk,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: accentPink,
                          backgroundColor: GiftShopColors.polarSky.withAlpha(
                            90,
                          ),
                          showCheckmark: false,
                          onSelected: (_) => onCategorySelected(chip),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _apiContent(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _apiContent(BuildContext context) => FutureBuilder<Item>(
    future: productsFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator(),
          ),
        );
      }
      if (snapshot.hasError) {
        final error = snapshot.error;
        final message =
            error is FirebaseException && error.code == 'permission-denied'
            ? 'Firestore denied access. Confirm you are signed in, then publish '
                  'the rules in firestore.rules to the prosforagiftshop project.'
            : 'Could not load products.\n$error';
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onReloadProducts,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      final products = snapshot.data?.data ?? <Datum>[];
      if (products.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No products available.'),
          ),
        );
      }
      final query = searchQuery.trim().toLowerCase();
      final filteredProducts = products.where((item) {
        final matchesCategory =
            query.isNotEmpty ||
            selectedCategory == 'All' ||
            normalizeGiftCategory(item.category) ==
                normalizeGiftCategory(selectedCategory);
        final searchableText =
            '${item.itemName} ${item.category} ${item.subtitle}'.toLowerCase();
        final matchesSearch = query.isEmpty || searchableText.contains(query);
        return matchesCategory && matchesSearch;
      }).toList();
      if (filteredProducts.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              query.isNotEmpty
                  ? 'No products found for "$query".'
                  : 'No products found for "$selectedCategory".',
            ),
          ),
        );
      }
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: filteredProducts.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width >= 450 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemBuilder: (context, index) {
          final item = filteredProducts[index];
          return _productCard(item, _categoryIcon(item.category));
        },
      );
    },
  );

  Widget _categoryItem(
    Map<String, Object> item,
    ValueChanged<String> onCategorySelected,
    String selectedCategory,
    Color primaryColor,
  ) {
    final categoryName = item['name']! as String;
    final isSelected =
        normalizeGiftCategory(selectedCategory) ==
        normalizeGiftCategory(categoryName);
    return InkWell(
      onTap: () => onCategorySelected(categoryName),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isSelected
                ? primaryColor.withAlpha(40)
                : Colors.grey.shade100,
            child: Icon(
              item['icon']! as IconData,
              color: primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            categoryName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _productCard(Datum item, IconData icon) {
    const accentPink = GiftShopColors.mauvelous;
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => onOpenProduct(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: GiftShopColors.cottonCandy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: productImage(item, icon),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.itemName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item.category,
                style: const TextStyle(
                  color: accentPink,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₱${item.pricePhp}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add to cart',
                    onPressed: () => onAddToCart(item),
                    icon: const Icon(
                      Icons.add_shopping_cart_outlined,
                      color: GiftShopColors.mauvelous,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
