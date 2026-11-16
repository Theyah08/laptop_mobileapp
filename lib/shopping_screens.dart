import 'package:flutter/material.dart';
import 'package:prosforagiftshop/gift_api.dart';
import 'package:prosforagiftshop/product.dart';

const Color _shopPink = Color(0xFFE08CA0);
const Color _checkoutBackground = Color(0xFFFFF7F9);

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.isWishlisted,
    required this.onToggleWishlist,
    required this.onAddToCart,
  });

  final Datum product;
  final bool Function(Datum) isWishlisted;
  final Future<void> Function(Datum) onToggleWishlist;
  final Future<bool> Function(Datum, int) onAddToCart;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int quantity = 1;
  bool isAddingToCart = false;

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

  Future<void> _addToCart() async {
    if (isAddingToCart) return;
    setState(() => isAddingToCart = true);
    try {
      final added = await widget.onAddToCart(widget.product, quantity);
      if (!mounted) return;
      if (!added) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.product.itemName} added to cart.')),
      );
    } finally {
      if (mounted) setState(() => isAddingToCart = false);
    }
  }

  Future<void> _toggleWishlist() async {
    await widget.onToggleWishlist(widget.product);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: _shopPink,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AspectRatio(
                aspectRatio: 1.1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: productImage(product, _categoryIcon(product.category)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.itemName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    tooltip: widget.isWishlisted(product)
                        ? 'Remove from wishlist'
                        : 'Add to wishlist',
                    onPressed: _toggleWishlist,
                    icon: Icon(
                      widget.isWishlisted(product)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: _shopPink,
                    ),
                  ),
                ],
              ),
              Text(
                product.category,
                style: const TextStyle(
                  color: _shopPink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '₱${product.pricePhp}',
                    style: const TextStyle(
                      color: _shopPink,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Chip(
                    avatar: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    label: Text('In stock'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(product.subtitle),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Decrease quantity',
                    onPressed: quantity > 1
                        ? () => setState(() => quantity--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Increase quantity',
                    onPressed: () => setState(() => quantity++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: isAddingToCart ? null : _addToCart,
            style: FilledButton.styleFrom(backgroundColor: _shopPink),
            icon: isAddingToCart
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.shopping_cart_outlined),
            label: Text('Add to Cart · ₱${product.pricePhp * quantity}'),
          ),
        ),
      ),
    );
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    required this.lines,
    required this.onQuantityChanged,
    required this.onBrowseCatalog,
    required this.onCheckout,
  });

  final List<CartLine> lines;
  final Future<bool> Function(Datum, int) onQuantityChanged;
  final VoidCallback onBrowseCatalog;
  final VoidCallback onCheckout;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late List<CartLine> lines;

  @override
  void initState() {
    super.initState();
    lines = [...widget.lines];
  }

  Future<void> _changeQuantity(Datum product, int quantity) async {
    final saved = await widget.onQuantityChanged(product, quantity);
    if (!saved || !mounted) return;
    setState(() {
      if (quantity < 1) {
        lines.removeWhere((line) => line.product.id == product.id);
      } else {
        final index = lines.indexWhere((line) => line.product.id == product.id);
        if (index >= 0) {
          lines[index] = lines[index].copyWith(quantity: quantity);
        }
      }
    });
  }

  int get subtotalPhp => lines.fold(0, (total, line) => total + line.totalPhp);

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My Cart'),
      backgroundColor: _shopPink,
      foregroundColor: Colors.white,
    ),
    body: lines.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_cart_outlined, size: 56),
                const SizedBox(height: 12),
                const Text('Your cart is empty.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: widget.onBrowseCatalog,
                  style: FilledButton.styleFrom(backgroundColor: _shopPink),
                  child: const Text('Browse gifts'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: lines.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final line = lines[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(
                              height: 76,
                              width: 76,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: productImage(
                                  line.product,
                                  _categoryIcon(line.product.category),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.product.itemName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('₱${line.product.pricePhp} each'),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Decrease quantity',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _changeQuantity(
                                          line.product,
                                          line.quantity - 1,
                                        ),
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                      Text('${line.quantity}'),
                                      IconButton(
                                        tooltip: 'Increase quantity',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _changeQuantity(
                                          line.product,
                                          line.quantity + 1,
                                        ),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                IconButton(
                                  tooltip: 'Remove item',
                                  onPressed: () =>
                                      _changeQuantity(line.product, 0),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: _shopPink,
                                  ),
                                ),
                                Text(
                                  '₱${line.totalPhp}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    children: [
                      _PriceRow(label: 'Subtotal', amountPhp: subtotalPhp),
                      const _PriceRow(label: 'Shipping', amountPhp: 0),
                      const Divider(),
                      _PriceRow(
                        label: 'Total',
                        amountPhp: subtotalPhp,
                        isTotal: true,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: widget.onCheckout,
                          style: FilledButton.styleFrom(
                            backgroundColor: _shopPink,
                          ),
                          child: const Text('Proceed to Checkout'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.lines,
    required this.wallet,
    required this.initialAddress,
    required this.onPlaceOrder,
    required this.onViewOrders,
    required this.onContinueShopping,
  });

  final List<CartLine> lines;
  final RewardWallet wallet;
  final String initialAddress;
  final Future<ShopOrder> Function(String address, bool applyRewards)
  onPlaceOrder;
  final VoidCallback onViewOrders;
  final VoidCallback onContinueShopping;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final formKey = GlobalKey<FormState>();
  final addressController = TextEditingController();
  bool isPlacingOrder = false;
  bool applyRewards = false;

  @override
  void initState() {
    super.initState();
    addressController.text = widget.initialAddress;
  }

  @override
  void dispose() {
    addressController.dispose();
    super.dispose();
  }

  int get subtotalPhp =>
      widget.lines.fold(0, (total, line) => total + line.totalPhp);

  RewardRedemption get rewardRedemption => calculateRewardRedemption(
    wallet: widget.wallet,
    subtotalPhp: subtotalPhp,
    applyRewards: applyRewards,
  );

  Widget _orderItemCard(CartLine line) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            height: 64,
            width: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: productImage(line.product, Icons.card_giftcard),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.product.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '₱${line.product.pricePhp} · Qty ${line.quantity}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₱${line.totalPhp}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );

  Future<void> _placeOrder() async {
    if (isPlacingOrder || !formKey.currentState!.validate()) return;
    setState(() => isPlacingOrder = true);
    try {
      final order = await widget.onPlaceOrder(
        addressController.text.trim(),
        applyRewards,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (context) => OrderConfirmationScreen(
            order: order,
            onViewOrders: widget.onViewOrders,
            onContinueShopping: widget.onContinueShopping,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout could not be completed: $error')),
      );
    } finally {
      if (mounted) setState(() => isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _checkoutBackground,
    appBar: AppBar(
      title: const Text('Checkout'),
      backgroundColor: _checkoutBackground,
      foregroundColor: Colors.black87,
      elevation: 0,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    Text(
                      'Your order (${widget.lines.fold<int>(0, (total, line) => total + line.quantity)})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...widget.lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _orderItemCard(line),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delivery address',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: addressController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Enter your delivery address',
                                filled: true,
                                fillColor: _checkoutBackground,
                                prefixIcon: const Icon(
                                  Icons.location_on_outlined,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter a delivery address'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SwitchListTile(
                        secondary: const Icon(
                          Icons.stars_outlined,
                          color: _shopPink,
                        ),
                        title: const Text('Apply rewards'),
                        subtitle: Text(
                          '${widget.wallet.points} points · 200 points = ₱10 off'
                          '${widget.wallet.creditPhp > 0 ? ' · ₱${widget.wallet.creditPhp} credit' : ''}',
                        ),
                        value: applyRewards,
                        activeTrackColor: _shopPink,
                        onChanged: (value) =>
                            setState(() => applyRewards = value),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Order summary',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _PriceRow(
                              label: 'Subtotal',
                              amountPhp: subtotalPhp,
                            ),
                            const _PriceRow(label: 'Shipping', amountPhp: 0),
                            if (rewardRedemption.discountPhp > 0)
                              _PriceRow(
                                label: 'Rewards discount',
                                amountPhp: -rewardRedemption.discountPhp,
                              ),
                            const Divider(height: 20),
                            _PriceRow(
                              label: 'Total',
                              amountPhp:
                                  subtotalPhp - rewardRedemption.discountPhp,
                              isTotal: true,
                            ),
                            if (applyRewards &&
                                rewardRedemption.discountPhp > 0) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Using ${rewardRedemption.pointsRedeemed} points and ₱${rewardRedemption.creditUsedPhp} reward credit.',
                                  style: const TextStyle(color: _shopPink),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Demo checkout: no payment will be collected. The order is saved on this device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: isPlacingOrder ? null : _placeOrder,
                    style: FilledButton.styleFrom(
                      backgroundColor: _shopPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: isPlacingOrder
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Confirm Checkout · ₱${subtotalPhp - rewardRedemption.discountPhp}',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.order,
    required this.onViewOrders,
    required this.onContinueShopping,
  });

  final ShopOrder order;
  final VoidCallback onViewOrders;
  final VoidCallback onContinueShopping;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: _shopPink, size: 84),
            const SizedBox(height: 16),
            const Text(
              'Order Placed!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Thank you for shopping with Prosfora Gift Shop!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text('Order #${order.id} · ₱${order.totalPhp}'),
            const SizedBox(height: 20),
            SizedBox(
              width: 240,
              child: FilledButton(
                onPressed: onViewOrders,
                style: FilledButton.styleFrom(backgroundColor: _shopPink),
                child: const Text('View My Orders'),
              ),
            ),
            TextButton(
              onPressed: onContinueShopping,
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    ),
  );
}

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({
    super.key,
    required this.wallet,
    required this.orders,
    required this.onRedeem,
  });

  final RewardWallet wallet;
  final List<ShopOrder> orders;
  final Future<void> Function() onRedeem;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Card(
        color: _shopPink,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.stars, color: Colors.white, size: 38),
              Text(
                '${wallet.points}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Available Points',
                style: TextStyle(color: Colors.white),
              ),
              if (wallet.creditPhp > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '₱${wallet.creditPhp} reward credit available',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Available rewards',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.card_giftcard, color: _shopPink),
          title: const Text('₱10 reward credit'),
          subtitle: const Text(
            'Redeem 200 points · Earn 1 point per ₱100 spent',
          ),
          trailing: FilledButton(
            onPressed: wallet.points >= 200 ? onRedeem : null,
            style: FilledButton.styleFrom(backgroundColor: _shopPink),
            child: const Text('Redeem'),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Recent transactions',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      if (orders.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text('Place an order to start earning points.'),
        )
      else
        ...orders.map(
          (order) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.stars_outlined, color: _shopPink),
            title: Text('Order #${order.id}'),
            subtitle: Text(_formatOrderDate(order.orderedAt)),
            trailing: Text('+${order.pointsEarned}'),
          ),
        ),
    ],
  );
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amountPhp,
    this.isTotal = false,
  });

  final String label;
  final int amountPhp;
  final bool isTotal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 17 : 14,
            ),
          ),
        ),
        Text(
          '${amountPhp < 0 ? '- ' : ''}₱${amountPhp.abs()}',
          style: TextStyle(
            color: isTotal ? _shopPink : null,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 17 : 14,
          ),
        ),
      ],
    ),
  );
}

String _formatOrderDate(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';
