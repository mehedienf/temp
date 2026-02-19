class ItemModel {
  final String id;
  final String name;
  final double unitPrice;

  ItemModel({required this.id, required this.name, required this.unitPrice});

  factory ItemModel.fromJson(Map<String, dynamic> json) => ItemModel(
    id: json['id'] as String,
    name: json['name'] as String,
    unitPrice: (json['unitPrice'] as num).toDouble(),
  );
}
