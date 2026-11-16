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

enum _OrderSort { newest, oldest, highestTotal, lowestTotal }

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.orders,
    required this.initialStatus,
    required this.onCancelOrder,
    required this.onReorderOrder,
  });

  final List<ShopOrder> orders;
  final String initialStatus;
  final Future<bool> Function(ShopOrder order) onCancelOrder;
  final Future<bool> Function(ShopOrder order) onReorderOrder;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String searchQuery = '';
  _OrderSort sort = _OrderSort.newest;

  int get initialTabIndex {
    final statusIndex = demoOrderStatuses.indexOf(widget.initialStatus);
    return statusIndex < 0 ? 0 : statusIndex + 1;
  }

  List<ShopOrder> _ordersFor(String status) {
    final query = searchQuery.trim().toLowerCase();
    final filtered = widget.orders.where((order) {
      final matchesStatus = status == 'All' || order.status == status;
      final searchableText = [
        order.id,
        order.status,
        order.shippingAddress,
        ...order.lines.map((line) => line.product.itemName),
      ].join(' ').toLowerCase();
      return matchesStatus && (query.isEmpty || searchableText.contains(query));
    }).toList();

    switch (sort) {
      case _OrderSort.newest:
        filtered.sort((a, b) => b.orderedAt.compareTo(a.orderedAt));
      case _OrderSort.oldest:
        filtered.sort((a, b) => a.orderedAt.compareTo(b.orderedAt));
      case _OrderSort.highestTotal:
        filtered.sort((a, b) => b.totalPhp.compareTo(a.totalPhp));
      case _OrderSort.lowestTotal:
        filtered.sort((a, b) => a.totalPhp.compareTo(b.totalPhp));
    }
    return filtered;
  }

  Future<void> _showSortOptions() async {
    final selectedSort = await showModalBottomSheet<_OrderSort>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Sort orders',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final option in _OrderSort.values)
              ListTile(
                title: Text(switch (option) {
                  _OrderSort.newest => 'Newest first',
                  _OrderSort.oldest => 'Oldest first',
                  _OrderSort.highestTotal => 'Highest total',
                  _OrderSort.lowestTotal => 'Lowest total',
                }),
                trailing: sort == option
                    ? const Icon(Icons.check, color: Color(0xFFE08CA0))
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      ),
    );
    if (selectedSort != null && mounted) {
      setState(() => sort = selectedSort);
    }
  }

  Widget _orderList(String status) => _OrderList(
    orders: _ordersFor(status),
    onCancelOrder: widget.onCancelOrder,
    onReorderOrder: widget.onReorderOrder,
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: demoOrderStatuses.length + 1,
    initialIndex: initialTabIndex,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'My Orders',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${widget.orders.length} orders',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by order or item',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () => setState(() => searchQuery = ''),
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: _showSortOptions,
                icon: const Icon(Icons.tune),
                label: const Text('Filter'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE08CA0),
                ),
              ),
            ],
          ),
        ),
        TabBar(
          isScrollable: true,
          labelColor: const Color(0xFFE08CA0),
          tabs: [
            const Tab(text: 'All'),
            for (final status in demoOrderStatuses) Tab(text: status),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              _orderList('All'),
              for (final status in demoOrderStatuses) _orderList(status),
            ],
          ),
        ),
      ],
    ),
  );
}

class DemoOrderStatusScreen extends StatefulWidget {
  const DemoOrderStatusScreen({
    super.key,
    required this.orders,
    required this.onStatusChanged,
  });

  final List<ShopOrder> orders;
  final Future<bool> Function(ShopOrder order, String status) onStatusChanged;

  @override
  State<DemoOrderStatusScreen> createState() => _DemoOrderStatusScreenState();
}

class _DemoOrderStatusScreenState extends State<DemoOrderStatusScreen> {
  late List<ShopOrder> orders;
  final Set<String> savingOrderIds = {};

  @override
  void initState() {
    super.initState();
    orders = [...widget.orders];
  }

  Future<void> _changeStatus(ShopOrder order, String status) async {
    if (status == order.status || savingOrderIds.contains(order.id)) return;
    setState(() => savingOrderIds.add(order.id));
    final saved = await widget.onStatusChanged(order, status);
    if (!mounted) return;
    setState(() {
      savingOrderIds.remove(order.id);
      if (saved) {
        orders = orders
            .map(
              (current) => current.id == order.id
                  ? current.copyWith(status: status)
                  : current,
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Demo order statuses'),
      backgroundColor: const Color(0xFFE08CA0),
      foregroundColor: Colors.white,
    ),
    body: orders.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No demo orders yet. Orders you place will appear here.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = orders[index];
              final isSaving = savingOrderIds.contains(order.id);
              final selectedStatus = demoOrderStatuses.contains(order.status)
                  ? order.status
                  : 'Processing';
              return Card(
                child: ListTile(
                  title: Text(
                    'Order #${order.id}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${order.orderedAt.day}/${order.orderedAt.month}/${order.orderedAt.year} · ₱${order.totalPhp}',
                  ),
                  trailing: isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : DropdownButton<String>(
                          value: selectedStatus,
                          items: demoOrderStatuses
                              .map(
                                (status) => DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(status),
                                ),
                              )
                              .toList(),
                          onChanged: (status) {
                            if (status != null) {
                              _changeStatus(order, status);
                            }
                          },
                        ),
                ),
              );
            },
          ),
  );
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.onCancelOrder,
    required this.onReorderOrder,
  });

  final List<ShopOrder> orders;
  final Future<bool> Function(ShopOrder order) onCancelOrder;
  final Future<bool> Function(ShopOrder order) onReorderOrder;

  IconData _categoryIcon(String category) {
    switch (normalizeGiftCategory(category)) {
      case 'Flowers':
        return Icons.local_florist;
      case 'Mugs':
        return Icons.coffee;
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
        final statusColor = switch (order.status) {
          'Completed' => Colors.green.shade100,
          'Cancelled' => Colors.grey.shade300,
          'Pending' => Colors.orange.shade100,
          _ => const Color(0xFFFCE4EC),
        };
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                      backgroundColor: statusColor,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                Text(
                  '${order.orderedAt.day}/${order.orderedAt.month}/${order.orderedAt.year}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          for (final line in order.lines.take(3))
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: SizedBox(
                                width: 42,
                                height: 42,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: productImage(
                                    line.product,
                                    _categoryIcon(line.product.category),
                                  ),
                                ),
                              ),
                            ),
                          if (order.lines.length > 3)
                            Text('+${order.lines.length - 3}'),
                        ],
                      ),
                    ),
                    Text(
                      '₱${order.totalPhp}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showOrderDetails(context, order),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE08CA0),
                          side: const BorderSide(color: Color(0xFFE08CA0)),
                        ),
                        child: const Text('View Details'),
                      ),
                    ),
                    if (order.status == 'Processing') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _confirmCancel(context, order),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                    if (order.status == 'Completed') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _reorder(context, order),
                          icon: const Icon(Icons.replay),
                          label: const Text('Reorder'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE08CA0),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmCancel(BuildContext context, ShopOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text('Are you sure you want to cancel order #${order.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final cancelled = await onCancelOrder(order);
    if (!context.mounted || !cancelled) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Order #${order.id} cancelled.')));
  }

  Future<void> _reorder(BuildContext context, ShopOrder order) async {
    final reordered = await onReorderOrder(order);
    if (!context.mounted || !reordered) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order #${order.id} added to your cart.')),
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
