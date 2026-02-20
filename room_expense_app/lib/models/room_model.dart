import 'item_model.dart';
import 'user_model.dart';

class RoomModel {
  final String id;
  final String code;
  final String name;
  final String? createdBy;
  final bool isConfirmed;
  // userId -> UserModel
  final Map<String, UserModel> members;
  // itemId -> ItemModel
  final Map<String, ItemModel> items;

  RoomModel({
    required this.id,
    required this.code,
    required this.name,
    this.createdBy,
    this.isConfirmed = false,
  }) : members = {},
       items = {};

  RoomModel.full({
    required this.id,
    required this.code,
    required this.name,
    this.createdBy,
    this.isConfirmed = false,
    required this.members,
    required this.items,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    final itemsMap = <String, ItemModel>{};
    for (final i in (json['items'] as List<dynamic>? ?? [])) {
      final item = ItemModel.fromJson(i as Map<String, dynamic>);
      itemsMap[item.id] = item;
    }
    final membersMap = <String, UserModel>{};
    for (final m in (json['members'] as List<dynamic>? ?? [])) {
      final user = UserModel.fromJson(m as Map<String, dynamic>);
      membersMap[user.id] = user;
    }
    return RoomModel.full(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      createdBy: json['createdBy'] as String?,
      isConfirmed: json['isConfirmed'] == true,
      items: itemsMap,
      members: membersMap,
    );
  }

  double get grandTotal =>
      members.values.fold(0.0, (sum, u) => sum + u.cartTotal);
}
