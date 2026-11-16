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

## Firebase product catalog

Products are stored in the `products` Cloud Firestore collection in the
configured `prosforagiftshop` Firebase project. On the first load, if that
collection is empty, the app imports the saved local catalog; if there are no
saved products, it imports the starter catalog. The import runs once across app
installations. Product reads and changes use Firestore; there is no MockAPI
catalog connection.

The rules require authentication to read or change products and validate the
product fields. Publish them in Firebase Console under **Firestore Database >
Rules**, or with `firebase deploy --only firestore:rules` after installing and
signing in to the Firebase CLI for the configured project. If the app shows a
Firestore `permission-denied` error, these rules have not been published to the
active project or the user is not signed in. The rules allow any signed-in
user to edit the catalog; restrict write rules to an admin claim before using
this with untrusted users.

Profile details are stored separately in `profiles/{uid}`. The profile rules
allow each signed-in user to read and update only their own name, email, phone,
and address. Checkout pre-fills the saved address and refreshes it when an
order is placed.

Bundled product images are referenced by their asset paths. Images picked from
a device for products or profiles are still saved as local paths (or browser
data URLs); Firebase Storage is needed to share uploaded photos across devices.

## Shopping demo

The app uses a shared pastel gift-shop theme: Mauvelous for headers, Cotton
Candy for Wishlist, Lilac Fizz for Rewards, Polar Sky for Cart/Pending, and
Denim for Cancelled order accents, with dark ink text for readability and a
cool muted coconut-white canvas.

The signed-in app supports product details, wishlist, cart quantity updates,
delivery-address checkout, order history, and reward points. Cart, demo orders,
and reward balances are saved locally on the current device under the signed-in
account. Checkout is a local demonstration only: it does not collect payment or
send an order to a fulfillment service. Customers earn 1 point per PHP 100
spent. At checkout, rewards are optional; every 200 points apply PHP 10 off,
up to the order subtotal. The Rewards screen can also convert 200 points into
PHP 10 of local reward credit. Demo order statuses can be changed in Settings
and are saved with the local order history. Processing orders can be cancelled
after confirmation, and completed orders can be reordered into the cart.
