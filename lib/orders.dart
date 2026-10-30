import 'package:flutter/material.dart';
import 'package:prosforagiftshop/gift_api.dart';
import 'package:prosforagiftshop/product.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({
    super.key,
    required this.userDataLoading,
    required this.productsFuture,
    required this.wishlistIds,
    required this.onOpenProduct,
    required this.onToggleWishlist,
  });

  final bool userDataLoading;
  final Future<Item> productsFuture;
  final Set<String> wishlistIds;
  final ValueChanged<Datum> onOpenProduct;
  final Future<void> Function(Datum) onToggleWishlist;

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
    if (userDataLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<Item>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load Wishlist: ${snapshot.error}'),
          );
        }
        final saved = (snapshot.data?.data ?? <Datum>[])
            .where((product) => wishlistIds.contains(product.id))
            .toList();
        if (saved.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_border, size: 52, color: Colors.black26),
                SizedBox(height: 10),
                Text('Your Wishlist is empty.'),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: saved.length,
          itemBuilder: (context, index) {
            final item = saved[index];
            return Card(
              child: ListTile(
                leading: SizedBox(
                  width: 54,
                  height: 54,
                  child: productImage(item, _categoryIcon(item.category)),
                ),
                title: Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${item.category} · ₱${item.pricePhp}'),
                onTap: () => onOpenProduct(item),
                trailing: IconButton(
                  tooltip: 'Remove from Wishlist',
                  onPressed: () => onToggleWishlist(item),
                  icon: const Icon(Icons.favorite, color: Color(0xFFE08CA0)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 54, color: Colors.black26),
          SizedBox(height: 12),
          Text(
            'No orders yet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          SizedBox(height: 6),
          Text(
            'Order placement and payment are not available in this app yet. No purchases are recorded.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
