import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prosforagiftshop/gift_api.dart';

class ProductEditorDialog extends StatefulWidget {
  const ProductEditorDialog({
    super.key,
    required this.product,
    required this.userStore,
  });

  final Datum? product;
  final UserLocalStore userStore;

  @override
  State<ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<ProductEditorDialog> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController nameController;
  late final TextEditingController priceController;
  late final TextEditingController subtitleController;
  late String selectedCategory;
  String? selectedImage;
  String? selectedImagePath;
  bool isPickingImage = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    nameController = TextEditingController(text: product?.itemName ?? '');
    priceController = TextEditingController(
      text: product == null ? '' : product.pricePhp.toString(),
    );
    subtitleController = TextEditingController(text: product?.subtitle ?? '');
    selectedCategory = normalizeGiftCategory(
      product?.category ?? giftProductCategories.first,
    );
    selectedImage =
        product?.imageAsset ??
        (product == null
            ? giftProductImageAssets.first
            : imageAssetForProduct(product));
    selectedImagePath = product?.imagePath;
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    subtitleController.dispose();
    super.dispose();
  }

  Future<void> _pickProductPhoto() async {
    if (isPickingImage) return;
    setState(() => isPickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (!mounted || picked == null) return;
      final savedPath = await widget.userStore.persistImage(picked);
      if (!mounted) return;
      setState(() {
        selectedImagePath = savedPath;
        selectedImage = null;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo could not be saved: $error')),
      );
    } finally {
      if (mounted) setState(() => isPickingImage = false);
    }
  }

  void _save() {
    if (!formKey.currentState!.validate()) return;
    final price = int.tryParse(priceController.text.trim());
    if (price == null) return;
    Navigator.pop(
      context,
      Datum(
        id: widget.product?.id,
        imageAsset: selectedImage,
        imagePath: selectedImagePath,
        itemName: nameController.text.trim(),
        category: selectedCategory,
        pricePhp: price,
        subtitle: subtitleController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final previewFile = kIsWeb || selectedImagePath == null
        ? null
        : File(selectedImagePath!);
    final previewBytes = imageBytesFromDataUrl(selectedImagePath);

    return AlertDialog(
      title: Text(product == null ? 'Add Product' : 'Edit Product'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Product name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: giftProductCategories.contains(selectedCategory)
                    ? selectedCategory
                    : giftProductCategories.first,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: giftProductCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                validator: (value) =>
                    value == null ? 'Select a category' : null,
                onChanged: isPickingImage
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => selectedCategory = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price (PHP)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) {
                  final price = num.tryParse(value?.trim() ?? '');
                  if (price == null ||
                      price < 0 ||
                      price != price.roundToDouble()) {
                    return 'Enter a valid whole-number price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Subtitle / description',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              if (previewBytes != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 110,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      previewBytes,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ] else if (previewFile != null && previewFile.existsSync()) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 110,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      previewFile,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ] else if (selectedImage != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 110,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      selectedImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: isPickingImage ? null : _pickProductPhoto,
                  icon: isPickingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(
                    isPickingImage
                        ? 'Opening photos...'
                        : selectedImagePath == null
                        ? 'Choose photo'
                        : 'Replace photo',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isPickingImage ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isPickingImage ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE08CA0),
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Widget productImage(Datum item, IconData fallbackIcon) {
  final webImageBytes = imageBytesFromDataUrl(item.imagePath);
  if (webImageBytes != null) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        webImageBytes,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(fallbackIcon, color: const Color(0xFFE08CA0), size: 40),
      ),
    );
  }
  if (!kIsWeb && item.imagePath != null && File(item.imagePath!).existsSync()) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(item.imagePath!),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(fallbackIcon, color: const Color(0xFFE08CA0), size: 40),
      ),
    );
  }
  final asset = imageAssetForProduct(item);
  if (asset == null) {
    return Icon(fallbackIcon, color: const Color(0xFFE08CA0), size: 40);
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.asset(
      asset,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(fallbackIcon, color: const Color(0xFFE08CA0), size: 40),
    ),
  );
}
