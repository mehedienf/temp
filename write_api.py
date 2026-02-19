content = """import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/item_model.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';

class ApiService {
  // Android emulator -> 10.0.2.2 maps to host machine's localhost
  // iOS simulator   -> localhost or 127.0.0.1
  // Real device     -> use your machine's local IP e.g. 192.168.x.x
  static const String _base = 'http://10.0.2.2:3000';

  static final _client = http.Client();

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
  };

  // ── Error helper ──────────────────────────────────────────────────────────
  static Never _throw(http.Response res) {
    final body = jsonDecode(res.body);
    throw Exception(body['error'] ?? 'Server error ${res.statusCode}');
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Sign up a new user. Returns UserModel on success.
  static Future<UserModel> signup(
    String username,
    String name,
    String password,
  ) async {
    final res = await _client.post(
      Uri.parse('\$_base/auth/signup'),
      headers: _headers,
      body: jsonEncode({'username': username, 'name': name, 'password': password}),
    );
    if (res.statusCode != 201) _throw(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return UserModel.fromJson({...data, 'cart': []});
  }

  /// Log in an existing user. Returns UserModel on success.
  static Future<UserModel> login(String username, String password) async {
    final res = await _client.post(
      Uri.parse('\$_base/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200) _throw(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return UserModel.fromJson({...data, 'cart': []});
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  /// Returns the list of rooms the user has joined.
  static Future<List<RoomModel>> getUserRooms(String userId) async {
    final res = await _client.get(Uri.parse('\$_base/users/\$userId/rooms'));
    if (res.statusCode != 200) _throw(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((r) => RoomModel.fromJson({
              ...r as Map<String, dynamic>,
              'items': [],
              'members': [],
            }))
        .toList();
  }

  // ── Rooms ─────────────────────────────────────────────────────────────────

  /// Creates a room and returns the RoomModel.
  static Future<RoomModel> createRoom(String name, String userId) async {
    final res = await _client.post(
      Uri.parse('\$_base/rooms'),
      headers: _headers,
      body: jsonEncode({'name': name, 'userId': userId}),
    );
    if (res.statusCode != 201) _throw(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return RoomModel.fromJson({...data, 'items': [], 'members': []});
  }

  /// Joins a room by its code and returns the RoomModel.
  static Future<RoomModel> joinRoom(String code, String userId) async {
    final res = await _client.post(
      Uri.parse('\$_base/rooms/join'),
      headers: _headers,
      body: jsonEncode({'code': code, 'userId': userId}),
    );
    if (res.statusCode == 404) throw Exception('Room not found');
    if (res.statusCode != 200) _throw(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return RoomModel.fromJson({...data, 'items': [], 'members': []});
  }

  /// Fetches full room data (members + items + carts).
  static Future<RoomModel> getRoom(String roomId) async {
    final res = await _client.get(Uri.parse('\$_base/rooms/\$roomId'));
    if (res.statusCode != 200) _throw(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return RoomModel.fromJson(data);
  }

  // ── Items ─────────────────────────────────────────────────────────────────

  static Future<ItemModel> addItem(
    String roomId,
    String name,
    double unitPrice,
  ) async {
    final res = await _client.post(
      Uri.parse('\$_base/rooms/\$roomId/items'),
      headers: _headers,
      body: jsonEncode({'name': name, 'unitPrice': unitPrice}),
    );
    if (res.statusCode != 201) _throw(res);
    return ItemModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> deleteItem(String roomId, String itemId) async {
    final res = await _client.delete(
      Uri.parse('\$_base/rooms/\$roomId/items/\$itemId'),
    );
    if (res.statusCode != 200) _throw(res);
  }

  // ── Cart ──────────────────────────────────────────────────────────────────

  static Future<void> updateCart(
    String userId,
    String itemId,
    int quantity,
  ) async {
    final res = await _client.put(
      Uri.parse('\$_base/users/\$userId/cart/\$itemId'),
      headers: _headers,
      body: jsonEncode({'quantity': quantity}),
    );
    if (res.statusCode != 200) _throw(res);
  }

  static Future<void> removeFromCart(String userId, String itemId) async {
    final res = await _client.delete(
      Uri.parse('\$_base/users/\$userId/cart/\$itemId'),
    );
    if (res.statusCode != 200) _throw(res);
  }
}
"""

with open(
    "/Volumes/Volume1/Project/temp/room_expense_app/lib/services/api_service.dart", "w"
) as f:
    f.write(content)
print("Done")
