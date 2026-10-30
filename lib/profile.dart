import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:prosforagiftshop/gift_api.dart';

Future<String?> showProfileEditDialog({
  required BuildContext context,
  required User user,
  required String phone,
  required Future<void> Function(String name, String phone) onSave,
}) async {
  final nameController = TextEditingController(text: user.displayName ?? '');
  final phoneController = TextEditingController(text: phone);
  final formKey = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit profile'),
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
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, phoneController.text.trim());
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
  return result;
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.phone,
    required this.photoPath,
    required this.onEditProfile,
    required this.onChangePhoto,
    required this.onSignOut,
  });

  final User? user;
  final String phone;
  final String? photoPath;
  final VoidCallback onEditProfile;
  final VoidCallback onChangePhoto;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final currentUser = user;
    if (currentUser == null) {
      return const Center(child: Text('Sign in to view your profile.'));
    }
    final localPhoto = photoPath;
    final photoBytes = imageBytesFromDataUrl(localPhoto);
    final ImageProvider<Object>? photoProvider = photoBytes != null
        ? MemoryImage(photoBytes)
        : (!kIsWeb && localPhoto != null && File(localPhoto).existsSync()
              ? FileImage(File(localPhoto))
              : (currentUser.photoURL == null
                    ? null
                    : NetworkImage(currentUser.photoURL!)));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFFFCE4EC),
                backgroundImage: photoProvider,
                child: localPhoto == null && currentUser.photoURL == null
                    ? const Icon(
                        Icons.person,
                        size: 46,
                        color: Color(0xFFE08CA0),
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
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onEditProfile,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit profile'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE08CA0),
            foregroundColor: Colors.white,
          ),
        ),
        TextButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Sign out', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.user,
    required this.onOpenProfile,
    required this.onClearCatalog,
    required this.onSignOut,
  });

  final User? user;
  final VoidCallback onOpenProfile;
  final VoidCallback onClearCatalog;
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
          'Wishlist, profile phone, and profile photo are stored locally on this device under your Firebase account ID. They are not synced between devices.',
        ),
      ),
      ListTile(
        leading: const Icon(Icons.cleaning_services_outlined),
        title: const Text('Clear cached catalog'),
        subtitle: const Text('The catalog will be downloaded again next time'),
        onTap: onClearCatalog,
      ),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Sign out', style: TextStyle(color: Colors.red)),
        onTap: onSignOut,
      ),
    ],
  );
}
