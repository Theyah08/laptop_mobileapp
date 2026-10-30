import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prosforagiftshop/gift_api.dart';
import 'package:prosforagiftshop/item_catalog_screen.dart';
import 'package:prosforagiftshop/product.dart';
import 'package:prosforagiftshop/orders.dart';
import 'package:prosforagiftshop/profile.dart';

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
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController searchController = TextEditingController();
  final HttpGiftCatalogStore catalogStore = HttpGiftCatalogStore();
  final UserLocalStore userStore = UserLocalStore();

  int screenIndex = 0;
  late bool showNavigationDrawer;
  String selectedCategory = 'All';
  String searchQuery = '';
  late Future<Item> productsFuture;
  Set<String> wishlistIds = {};
  String profilePhone = '';
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => userDataLoading = false);
      return;
    }
    final values = await Future.wait([
      userStore.loadWishlist(uid),
      userStore.loadPhone(uid),
      userStore.loadProfilePhoto(uid),
    ]);
    if (!mounted) return;
    setState(() {
      wishlistIds = values[0] as Set<String>;
      profilePhone = values[1] as String;
      profilePhotoPath = values[2] as String?;
      userDataLoading = false;
    });
  }

  void _selectScreen(int selectedScreen) {
    setState(() => screenIndex = selectedScreen);
  }

  void _handleScreenChanged(int selectedScreen) {
    setState(() => screenIndex = selectedScreen);
  }

  Future<Item> _reloadProducts() {
    final future = catalogStore.loadCatalog();
    setState(() {
      productsFuture = future;
    });
    return future;
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
          isWishlisted: _isWishlisted,
          onToggleWishlist: _toggleWishlist,
          onOpenProduct: _showProductDetails,
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
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

  IconData _categoryIcon(String category) {
    switch (normalizeGiftCategory(category)) {
      case 'Mugs and Drinkware':
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

  void _showProductDetails(Datum product) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 190,
                width: double.infinity,
                child: productImage(product, _categoryIcon(product.category)),
              ),
              const SizedBox(height: 14),
              Text(
                product.itemName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                product.category,
                style: const TextStyle(color: Color(0xFF00A884)),
              ),
              const SizedBox(height: 8),
              Text(product.subtitle),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '₱${product.pricePhp}',
                      style: const TextStyle(
                        color: Color(0xFFE08CA0),
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _isWishlisted(product)
                        ? 'Remove from wishlist'
                        : 'Add to wishlist',
                    onPressed: () => _toggleWishlist(product),
                    icon: Icon(
                      _isWishlisted(product)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: const Color(0xFFE08CA0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(User user) async {
    final result = await showProfileEditDialog(
      context: context,
      user: user,
      phone: profilePhone,
      onSave: (name, phone) async {
        final current = FirebaseAuth.instance.currentUser;
        if (current == null) return;
        await current.updateDisplayName(name);
        await userStore.savePhone(current.uid, phone);
        await current.reload();
      },
    );
    if (result != null && mounted) {
      setState(() => profilePhone = result);
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

  Future<void> _confirmClearCatalog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cached catalog?'),
        content: const Text(
          'This removes local product changes and reloads the original public catalog next time. Wishlist and profile data will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final oldProducts = (await productsFuture).data;
      final favoriteFingerprints = oldProducts
          .where((product) => wishlistIds.contains(product.id))
          .map(_productFingerprint)
          .toSet();
      await userStore.resetLocalCatalog();
      final refreshed = await catalogStore.loadCatalog();
      final refreshedWishlist = refreshed.data
          .where(
            (product) =>
                favoriteFingerprints.contains(_productFingerprint(product)),
          )
          .map((product) => product.id)
          .toSet();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await userStore.saveWishlist(uid, refreshedWishlist);
      if (!mounted) return;
      setState(() {
        productsFuture = Future.value(refreshed);
        wishlistIds = refreshedWishlist;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Catalog could not be reset: $error')),
      );
    }
  }

  String _productFingerprint(Datum product) =>
      '${product.itemName}|${normalizeGiftCategory(product.category)}|'
      '${product.pricePhp}|${product.subtitle}';

  Widget _buildSelectedScreen(User? user) {
    switch (screenIndex) {
      case 1:
        return const OrdersScreen();
      case 2:
        return SettingsScreen(
          user: user,
          onOpenProfile: () => _selectScreen(4),
          onClearCatalog: _confirmClearCatalog,
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
          photoPath: profilePhotoPath,
          onEditProfile: user == null ? () {} : () => _editProfile(user),
          onChangePhoto: user == null ? () {} : () => _changeProfilePhoto(user),
          onSignOut: _signOut,
        );
      default:
        return _buildDashboard(user);
    }
  }

  Widget _buildDashboard(User? user) => HomeDashboard(
    user: user,
    productsFuture: productsFuture,
    searchController: searchController,
    searchQuery: searchQuery,
    selectedCategory: selectedCategory,
    wishlistCount: wishlistIds.length,
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
    isWishlisted: _isWishlisted,
    onToggleWishlist: _toggleWishlist,
    onOpenProduct: _showProductDetails,
  );

  List<Widget> _buildAppBarActions() => [
    IconButton(
      tooltip: 'Manage product catalog',
      onPressed: _openItemCatalog,
      icon: const Icon(Icons.view_list_outlined),
    ),
  ];

  Widget _buildBottomBarScaffold(User? user) => Scaffold(
    key: scaffoldKey,
    appBar: AppBar(
      title: const Text('Prosfora Gift Shop'),
      backgroundColor: const Color(0xFFE08CA0),
      foregroundColor: Colors.white,
      actions: _buildAppBarActions(),
    ),
    drawer: _buildNavigationDrawer(user),
    body: _buildSelectedScreen(user),
    bottomNavigationBar: Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BottomNavigationBar(
          currentIndex: screenIndex.clamp(0, destinations.length - 1),
          onTap: _handleScreenChanged,
          backgroundColor: Colors.transparent,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white38,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: destinations
              .map(
                (destination) => BottomNavigationBarItem(
                  icon: destination.icon,
                  activeIcon: destination.selectedIcon,
                  label: destination.label,
                ),
              )
              .toList(),
        ),
      ),
    ),
  );

  Widget _buildNavigationDrawer(User? user) => NavigationDrawer(
    selectedIndex: screenIndex < destinations.length ? screenIndex : null,
    onDestinationSelected: (index) {
      _handleScreenChanged(index);
      Navigator.pop(context);
    },
    children: [
      UserAccountsDrawerHeader(
        decoration: const BoxDecoration(color: Color(0xFFE08CA0)),
        accountName: Text(
          user?.displayName?.isNotEmpty == true
              ? user!.displayName!
              : 'Prosfora Customer',
        ),
        accountEmail: Text(user?.email ?? 'No email'),
        currentAccountPicture: const CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.card_giftcard, color: Color(0xFFE08CA0)),
        ),
      ),
      ...destinations.map(
        (destination) => NavigationDrawerDestination(
          label: Text(destination.label),
          icon: destination.icon,
          selectedIcon: destination.selectedIcon,
        ),
      ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: const Text('My Profile'),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          Navigator.pop(context);
          _selectScreen(4);
        },
      ),
      ListTile(
        leading: const Icon(Icons.favorite_border),
        title: const Text('Wishlist'),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          Navigator.pop(context);
          _selectScreen(3);
        },
      ),
      ListTile(
        leading: const Icon(Icons.view_list_outlined),
        title: const Text('Item Catalog'),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          Navigator.pop(context);
          _openItemCatalog();
        },
      ),
      ListTile(
        leading: const Icon(Icons.notifications_outlined),
        title: const Text('Notifications'),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          Navigator.pop(context);
          _showInfo(
            'Notifications',
            'Push notifications are not configured in this app.',
          );
        },
      ),
      const Divider(),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
        onTap: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        },
      ),
    ],
  );

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerScaffold(User? user) => Scaffold(
    key: scaffoldKey,
    appBar: AppBar(
      title: const Text('Prosfora Gift Shop'),
      backgroundColor: const Color(0xFFE08CA0),
      foregroundColor: Colors.white,
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
    required this.user,
    required this.productsFuture,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.wishlistCount,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchAction,
    required this.onCategorySelected,
    required this.onReloadProducts,
    required this.isWishlisted,
    required this.onToggleWishlist,
    required this.onOpenProduct,
  });

  final User? user;
  final Future<Item> productsFuture;
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedCategory;
  final int wishlistCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onSearchAction;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onReloadProducts;
  final bool Function(Datum) isWishlisted;
  final Future<void> Function(Datum) onToggleWishlist;
  final ValueChanged<Datum> onOpenProduct;

  static const List<Map<String, Object>> _categories = [
    {'name': 'Flowers', 'icon': Icons.local_florist},
    {'name': 'Mugs and Drinkware', 'icon': Icons.coffee},
    {'name': 'Stationery', 'icon': Icons.edit_note},
    {'name': 'Plushies', 'icon': Icons.smart_toy_outlined},
    {'name': 'Fragrance', 'icon': Icons.science},
    {'name': 'Other Gifts', 'icon': Icons.card_giftcard},
  ];

  List<String> get _filterChips => ['All', ...giftProductCategories];

  IconData _categoryIcon(String category) {
    switch (normalizeGiftCategory(category)) {
      case 'Mugs and Drinkware':
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
    const primaryColor = Color(0xFFE08CA0);
    const accentTeal = Color(0xFF00A884);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: primaryColor.withAlpha(40),
                    child: const Icon(
                      Icons.person,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Good Morning,',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        user?.email?.split('@').first ?? 'Guest User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                          color: accentTeal,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          searchQuery.isEmpty ? Icons.search : Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2C2C2C), Color(0xFF1A1A1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today Special!',
                            style: TextStyle(
                              color: Colors.orange,
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
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: () => onCategorySelected('Flowers'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                            icon: const Icon(Icons.local_florist, size: 16),
                            label: const Text(
                              'Browse flowers',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white12,
                      child: Icon(
                        Icons.local_florist,
                        size: 40,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 75,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final item = _categories[index];
                    final categoryName = item['name']! as String;
                    final isSelected =
                        normalizeGiftCategory(selectedCategory) ==
                        normalizeGiftCategory(categoryName);
                    return InkWell(
                      onTap: () => onCategorySelected(categoryName),
                      borderRadius: BorderRadius.circular(28),
                      child: Column(
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
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Orders',
                      'No orders',
                      Icons.receipt_long_outlined,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      'Wishlist',
                      '$wishlistCount Items',
                      Icons.favorite_border,
                      Colors.pink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      'Rewards',
                      'Not available',
                      Icons.stars_outlined,
                      Colors.purple,
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
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: accentTeal,
                      backgroundColor: Colors.grey.shade100,
                      showCheckmark: false,
                      onSelected: (_) => onCategorySelected(chip),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _apiContent(context),
            ],
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
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                const SizedBox(height: 8),
                Text(
                  'Could not load products.\n${snapshot.error}',
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
      final filteredProducts = products.where((item) {
        final matchesCategory =
            selectedCategory == 'All' ||
            normalizeGiftCategory(item.category) ==
                normalizeGiftCategory(selectedCategory);
        final matchesSearch =
            searchQuery.isEmpty ||
            item.itemName.toLowerCase().contains(searchQuery);
        return matchesCategory && matchesSearch;
      }).toList();
      if (filteredProducts.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              searchQuery.isNotEmpty
                  ? 'No products found for "$searchQuery".'
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

  Widget _statCard(String title, String value, IconData icon, Color color) =>
      Container(
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
      );

  Widget _productCard(Datum item, IconData icon) {
    const accentTeal = Color(0xFF00A884);
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
                    color: const Color(0xFFFCE4EC),
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
                  color: accentTeal,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item.subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
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
                    tooltip: isWishlisted(item)
                        ? 'Remove from Wishlist'
                        : 'Add to Wishlist',
                    onPressed: () => onToggleWishlist(item),
                    icon: Icon(
                      isWishlisted(item)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: const Color(0xFFE08CA0),
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
