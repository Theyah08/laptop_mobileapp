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
  const OrdersScreen({super.key, required this.orders});

  final List<ShopOrder> orders;

  @override
  Widget build(BuildContext context) {
    final ordered = [...orders]
      ..sort((first, second) => second.orderedAt.compareTo(first.orderedAt));
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFFE08CA0),
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Pending'),
              Tab(text: 'Processing'),
              Tab(text: 'Completed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OrderList(orders: ordered),
                _OrderList(
                  orders: ordered
                      .where((order) => order.status == 'Pending')
                      .toList(),
                ),
                _OrderList(
                  orders: ordered
                      .where((order) => order.status == 'Processing')
                      .toList(),
                ),
                _OrderList(
                  orders: ordered
                      .where((order) => order.status == 'Completed')
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders});

  final List<ShopOrder> orders;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
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
            Text('Orders you place will appear here.'),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final order = orders[index];
        final productNames = order.lines.map((line) => line.product.itemName);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Order #${order.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Chip(
                      label: Text(order.status),
                      backgroundColor: order.status == 'Completed'
                          ? Colors.green.shade100
                          : const Color(0xFFFCE4EC),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                Text(
                  '${order.orderedAt.day}/${order.orderedAt.month}/${order.orderedAt.year}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  productNames.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '₱${order.totalPhp}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showOrderDetails(context, order),
                      child: const Text('View Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOrderDetails(BuildContext context, ShopOrder order) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${order.id}'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${order.orderedAt.day}/${order.orderedAt.month}/${order.orderedAt.year} · ${order.status}',
              ),
              if (order.shippingAddress.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Deliver to: ${order.shippingAddress}'),
              ],
              const Divider(),
              ...order.lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${line.product.itemName} x${line.quantity}',
                        ),
                      ),
                      Text('₱${line.totalPhp}'),
                    ],
                  ),
                ),
              ),
              const Divider(),
              if (order.voucherDiscountPhp > 0)
                Text('Rewards discount: -₱${order.voucherDiscountPhp}'),
              Text(
                'Total: ₱${order.totalPhp}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Demo order only. No payment was collected.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
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
}
