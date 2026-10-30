# prosforagiftshop

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Project Structure

```text
lib/
	main.dart                     App entry point and Firebase initialization
	firebase_options.dart          Generated Firebase platform configuration
	app/main_page.dart              Authentication-state routing
	data/gift_api.dart              Product model and local catalog/user storage
	features/auth/login_page.dart   Firebase email/password login
	features/catalog/home_page.dart Home coordinator, state, and navigation
	features/catalog/item_catalog_screen.dart Product list and catalog actions
	features/catalog/product_editor_dialog.dart Add/Edit form and photo picker
	features/catalog/product_image.dart Shared product image rendering
	features/home/home_dashboard.dart Dashboard layout and product cards
	features/wishlist/wishlist_screen.dart Saved products
	features/orders/orders_screen.dart Honest empty order-history state
	features/profile/profile_screen.dart Profile information and actions
	features/settings/settings_screen.dart Settings options
```

Run the app with `flutter pub get` followed by `flutter run`.

## Product REST API

The product catalog uses the REST endpoint configured as `productsApiUrl` in
`lib/gift_api.dart`. It expects a JSON array from GET, accepts JSON product
objects for POST and PUT, and uses each product's `id` as the item URL suffix
for PUT and DELETE.

The product API must permit requests from the app's platforms. If the API
collection is empty on first launch, the app imports the saved local catalog
when available, or otherwise imports the starter products from `giftCatalogUrl`.
The migration runs only once per installation, so deleting all remote products
does not cause the starter catalog to be restored.
