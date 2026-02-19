import 'item_model.dart';

class CartItemModel {
  final ItemModel item;
  int quantity;

  CartItemModel({required this.item, this.quantity = 1});

  double get total => item.unitPrice * quantity;

  factory CartItemModel.fromJson(Map<String, dynamic> json) => CartItemModel(
    item: ItemModel(
      id: json['itemId'] as String,
      name: json['itemName'] as String,
      unitPrice: (json['unitPrice'] as num).toDouble(),
    ),
    quantity: json['quantity'] as int,
  );
}
