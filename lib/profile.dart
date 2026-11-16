import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prosforagiftshop/main_page.dart';
import 'package:prosforagiftshop/gift_api.dart';

const _profileLilac = GiftShopColors.lilacFizz;
const _profileCottonCandy = GiftShopColors.cottonCandy;
const _profileMauvelous = GiftShopColors.mauvelous;
const _profilePolarSky = GiftShopColors.polarSky;
const _profileDenim = GiftShopColors.denim;

typedef ProfileEditResult = ({String phone, String address});

ImageProvider<Object>? profileImageProvider(
  String? localPhoto,
  String? photoUrl,
) {
  final photoBytes = imageBytesFromDataUrl(localPhoto);
  if (photoBytes != null) return MemoryImage(photoBytes);
  if (!kIsWeb && localPhoto != null && File(localPhoto).existsSync()) {
    return FileImage(File(localPhoto));
  }
  return photoUrl == null ? null : NetworkImage(photoUrl);
}

Future<ProfileEditResult?> showProfileEditDialog({
  required BuildContext context,
  required User user,
  required String phone,
  required String address,
  required Future<void> Function(String name, String phone, String address)
  onSave,
}) async {
  final nameController = TextEditingController(text: user.displayName ?? '');
  final phoneController = TextEditingController(text: phone);
  final addressController = TextEditingController(text: address);
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<ProfileEditResult>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit profile'),
      scrollable: true,
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Name is required'
                  : null,
            ),
            TextFormField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            TextFormField(
              controller: addressController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            try {
              await onSave(
                nameController.text.trim(),
                phoneController.text.trim(),
                addressController.text.trim(),
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, (
                  phone: phoneController.text.trim(),
                  address: addressController.text.trim(),
                ));
              }
            } catch (error) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Profile could not be saved: $error')),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  nameController.dispose();
  phoneController.dispose();
  addressController.dispose();
  return result;
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.phone,
    required this.address,
    required this.photoPath,
    required this.orderCount,
    required this.orders,
    required this.cartCount,
    required this.wishlistCount,
    required this.rewardPoints,
    required this.onEditProfile,
    required this.onChangePhoto,
    required this.onOpenOrders,
    required this.onOpenOrdersByStatus,
    required this.onOpenCart,
    required this.onOpenWishlist,
    required this.onOpenRewards,
    required this.onSignOut,
  });

  final User? user;
  final String phone;
  final String address;
  final String? photoPath;
  final int orderCount;
  final List<ShopOrder> orders;
  final int cartCount;
  final int wishlistCount;
  final int rewardPoints;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePhoto;
  final VoidCallback onOpenOrders;
  final ValueChanged<String> onOpenOrdersByStatus;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenWishlist;
  final VoidCallback onOpenRewards;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final currentUser = user;
    if (currentUser == null) {
      return const Center(child: Text('Sign in to view your profile.'));
    }
    final localPhoto = photoPath;
    final photoProvider = profileImageProvider(
      localPhoto,
      currentUser.photoURL,
    );
    final displayName = currentUser.displayName?.isNotEmpty == true
        ? currentUser.displayName!
        : 'Prosfora Customer';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: _profileCottonCandy,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.white,
                      backgroundImage: photoProvider,
                      child: photoProvider == null
                          ? const Icon(
                              Icons.person,
                              size: 36,
                              color: _profileMauvelous,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        tooltip: 'Change profile photo',
                        onPressed: onChangePhoto,
                        icon: const Icon(Icons.photo_camera_outlined),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _profileMauvelous,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GiftShopColors.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser.email ?? 'No email',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: GiftShopColors.ink),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: onEditProfile,
                  color: GiftShopColors.ink,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ProfileQuickBox(
                title: 'Cart',
                value: '$cartCount ${cartCount == 1 ? 'item' : 'items'}',
                icon: Icons.shopping_cart_outlined,
                tintColor: _profilePolarSky.withAlpha(110),
                accentColor: _profileDenim,
                onTap: onOpenCart,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ProfileQuickBox(
                title: 'Wishlist',
                value:
                    '$wishlistCount ${wishlistCount == 1 ? 'item' : 'items'}',
                icon: Icons.favorite_border,
                tintColor: _profileCottonCandy,
                accentColor: _profileMauvelous,
                onTap: onOpenWishlist,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ProfileQuickBox(
                title: 'Rewards',
                value: '$rewardPoints pts',
                icon: Icons.stars_outlined,
                tintColor: _profileLilac.withAlpha(75),
                accentColor: _profileLilac,
                onTap: onOpenRewards,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: _profileLilac.withAlpha(75)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'My Orders',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '$orderCount orders',
                      style: const TextStyle(
                        color: GiftShopColors.ink,
                        fontSize: 12,
                      ),
                    ),
                    TextButton(
                      onPressed: onOpenOrders,
                      child: const Text('View all'),
                    ),
                  ],
                ),
                SizedBox(
                  height: 92,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _ProfileOrderStatus(
                        title: 'Pending',
                        count: _countOrders('Pending'),
                        icon: Icons.payment_outlined,
                        accentColor: _profileDenim,
                        tintColor: _profilePolarSky.withAlpha(110),
                        onTap: () => onOpenOrdersByStatus('Pending'),
                      ),
                      _ProfileOrderStatus(
                        title: 'Processing',
                        count: _countOrders('Processing'),
                        icon: Icons.local_shipping_outlined,
                        accentColor: _profileMauvelous,
                        tintColor: _profileCottonCandy,
                        onTap: () => onOpenOrdersByStatus('Processing'),
                      ),
                      _ProfileOrderStatus(
                        title: 'Completed',
                        count: _countOrders('Completed'),
                        icon: Icons.check_circle_outline,
                        accentColor: _profileLilac,
                        tintColor: _profileLilac.withAlpha(75),
                        onTap: () => onOpenOrdersByStatus('Completed'),
                      ),
                      _ProfileOrderStatus(
                        title: 'Cancelled',
                        count: _countOrders('Cancelled'),
                        icon: Icons.cancel_outlined,
                        accentColor: _profileDenim,
                        tintColor: _profileDenim.withAlpha(55),
                        onTap: () => onOpenOrdersByStatus('Cancelled'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'My Account',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Name'),
                subtitle: Text(
                  currentUser.displayName?.isNotEmpty == true
                      ? currentUser.displayName!
                      : 'Not set',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(currentUser.email ?? 'Not available'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Phone'),
                subtitle: Text(phone.isEmpty ? 'Not set' : phone),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Address'),
                subtitle: Text(address.isEmpty ? 'Not set' : address),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onEditProfile,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: onSignOut,
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _countOrders(String status) =>
      orders.where((order) => order.status == status).length;
}

class _ProfileOrderStatus extends StatelessWidget {
  const _ProfileOrderStatus({
    required this.title,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.tintColor,
    required this.onTap,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color accentColor;
  final Color tintColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 82,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: tintColor,
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: GiftShopColors.ink),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: GiftShopColors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProfileQuickBox extends StatelessWidget {
  const _ProfileQuickBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.tintColor,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color tintColor;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: tintColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 82,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(height: 3),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GiftShopColors.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: GiftShopColors.ink, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.user,
    required this.onOpenProfile,
    required this.onManageDemoOrderStatuses,
    required this.onReloadCatalog,
    required this.onSignOut,
  });

  final User? user;
  final VoidCallback onOpenProfile;
  final VoidCallback onManageDemoOrderStatuses;
  final VoidCallback onReloadCatalog;
  final Future<void> Function() onSignOut;

  void _showInfo(BuildContext context, String title, String message) {
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

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      ListTile(
        leading: const Icon(Icons.manage_accounts_outlined),
        title: const Text('Account and profile'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpenProfile,
      ),
      ListTile(
        leading: const Icon(Icons.notifications_outlined),
        title: const Text('Notifications'),
        subtitle: const Text('Push notifications are not configured'),
        onTap: () => _showInfo(
          context,
          'Notifications',
          'Push notifications are not enabled in this app.',
        ),
      ),
      ListTile(
        leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('Privacy and account'),
        subtitle: Text(user?.email ?? 'Signed-in account'),
        onTap: () => _showInfo(
          context,
          'Privacy and account',
          'Profile name, email, phone, and address are saved in your private Firestore profile. Wishlist, cart, orders, rewards, and profile photo stay on this device.',
        ),
      ),
      ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: const Text('Reload product catalog'),
        subtitle: const Text('Refresh products from the catalog service'),
        onTap: onReloadCatalog,
      ),
      ListTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: const Text('Demo order statuses'),
        subtitle: const Text('Change the status of an existing demo order'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onManageDemoOrderStatuses,
      ),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Sign out', style: TextStyle(color: Colors.red)),
        onTap: onSignOut,
      ),
    ],
  );
}
