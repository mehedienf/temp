import 'cart_item_model.dart';

class UserModel {
  final String id;
  final String username;
  final String name;
  // itemId -> CartItemModel
  final Map<String, CartItemModel> cart;

  UserModel({required this.id, required this.username, required this.name})
    : cart = {};

  UserModel.withCart({
    required this.id,
    required this.username,
    required this.name,
    required this.cart,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final cartList = (json['cart'] as List<dynamic>? ?? []);
    final cartMap = <String, CartItemModel>{};
    for (final c in cartList) {
      final ci = CartItemModel.fromJson(c as Map<String, dynamic>);
      cartMap[ci.item.id] = ci;
    }
    return UserModel.withCart(
      id: json['id'] as String,
      username: json['username'] as String? ?? '',
      name: json['name'] as String,
      cart: cartMap,
    );
  }

  double get cartTotal => cart.values.fold(0.0, (sum, ci) => sum + ci.total);
}
