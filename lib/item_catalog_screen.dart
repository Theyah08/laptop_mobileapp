import 'package:flutter/material.dart';
import 'package:prosforagiftshop/gift_api.dart';
import 'package:prosforagiftshop/product.dart';

class ItemCatalogScreen extends StatefulWidget {
  const ItemCatalogScreen({
    super.key,
    required this.productsFuture,
    required this.loadProducts,
    required this.onAddProduct,
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.isWishlisted,
    required this.onToggleWishlist,
    required this.onOpenProduct,
  });

  final Future<Item> productsFuture;
  final Future<Item> Function() loadProducts;
  final Future<void> Function() onAddProduct;
  final Future<void> Function(Datum) onEditProduct;
  final Future<void> Function(Datum) onDeleteProduct;
  final bool Function(Datum) isWishlisted;
  final Future<void> Function(Datum) onToggleWishlist;
  final ValueChanged<Datum> onOpenProduct;

  @override
  State<ItemCatalogScreen> createState() => _ItemCatalogScreenState();
}

class _ItemCatalogScreenState extends State<ItemCatalogScreen> {
  late Future<Item> productsFuture;
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    productsFuture = widget.productsFuture;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _reloadProducts() {
    final future = widget.loadProducts();
    setState(() {
      productsFuture = future;
    });
  }

  IconData _getCategoryIcon(String category) {
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
    const accentColor = Color(0xFFE08CA0);
    const accentTeal = Color(0xFF00A884);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Catalog'),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Add product',
            onPressed: () async {
              await widget.onAddProduct();
              if (mounted) _reloadProducts();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                onChanged: (value) =>
                    setState(() => searchQuery = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search products by name',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            searchController.clear();
                            setState(() => searchQuery = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<Item>(
                future: productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Could not load products.',
                              style: TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _reloadProducts,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try again'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final products = snapshot.data?.data ?? <Datum>[];
                  final filteredProducts = products
                      .where(
                        (item) =>
                            item.itemName.toLowerCase().contains(searchQuery),
                      )
                      .toList();
                  if (filteredProducts.isEmpty) {
                    return Center(
                      child: Text(
                        products.isEmpty
                            ? 'No products available.'
                            : 'No products found for "$searchQuery".',
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final item = filteredProducts[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: InkWell(
                            onTap: () => widget.onOpenProduct(item),
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFCE4EC),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: productImage(
                                    item,
                                    _getCategoryIcon(item.category),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.itemName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        item.category,
                                        style: const TextStyle(
                                          color: accentTeal,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        item.subtitle,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₱${item.pricePhp}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: widget.isWishlisted(item)
                                          ? 'Remove from wishlist'
                                          : 'Add to wishlist',
                                      onPressed: () =>
                                          widget.onToggleWishlist(item),
                                      icon: Icon(
                                        widget.isWishlisted(item)
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                      ),
                                      color: accentColor,
                                    ),
                                    PopupMenuButton<String>(
                                      tooltip: 'Manage ${item.itemName}',
                                      onSelected: (action) async {
                                        if (action == 'edit') {
                                          await widget.onEditProduct(item);
                                        } else {
                                          await widget.onDeleteProduct(item);
                                        }
                                        if (mounted) _reloadProducts();
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
