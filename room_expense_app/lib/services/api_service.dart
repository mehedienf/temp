import 'dart:convert';

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
      Uri.parse('$_base/auth/signup'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'name': name,
        'password': password,
      }),
    );
    if (res.statusCode != 201) _throw(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return UserModel.fromJson({...data, 'cart': []});
  }

  /// Log in an existing user. Returns UserModel on success.
  static Future<UserModel> login(String username, String password) async {
    final res = await _client.post(
      Uri.parse('$_base/auth/login'),
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
    final res = await _client.get(Uri.parse('$_base/users/$userId/rooms'));
    if (res.statusCode != 200) _throw(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map(
          (r) => RoomModel.fromJson({
            ...r as Map<String, dynamic>,
            'items': [],
            'members': [],
          }),
        )
        .toList();
  }

  // ── Rooms ─────────────────────────────────────────────────────────────────

  /// Creates a room and returns the RoomModel.
  static Future<RoomModel> createRoom(String name, String userId) async {
    final res = await _client.post(
      Uri.parse('$_base/rooms'),
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
      Uri.parse('$_base/rooms/join'),
      headers: _headers,
      body: jsonEncode({'code': code, 'userId': userId}),
    );
    if (res.statusCode == 404) throw Exception('Room not found');
    if (res.statusCode != 200) _throw(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return RoomModel.fromJson({...data, 'items': [], 'members': []});
  }

  /// Leave a room. Pass [requesterId] = caller's userId.
  /// If requesterId != userId, backend treats it as an admin removal (hard delete).
  static Future<void> leaveRoom(
    String roomId,
    String userId, {
    String? requesterId,
  }) async {
    final req = http.Request(
      'DELETE',
      Uri.parse('$_base/rooms/$roomId/members/$userId'),
    );
    req.headers.addAll(_headers);
    req.body = jsonEncode({'requesterId': requesterId ?? userId});
    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) _throw(res);
  }

  /// Delete a room (admin only).
  static Future<void> deleteRoom(String roomId, String userId) async {
    final req = http.Request('DELETE', Uri.parse('$_base/rooms/$roomId'));
    req.headers.addAll(_headers);
    req.body = jsonEncode({'userId': userId});
    final streamedRes = await _client.send(req);
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode != 200) _throw(res);
  }

  /// Fetches full room data (members + items + carts).
  static Future<RoomModel> getRoom(String roomId) async {
    final res = await _client.get(Uri.parse('$_base/rooms/$roomId'));
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
      Uri.parse('$_base/rooms/$roomId/items'),
      headers: _headers,
      body: jsonEncode({'name': name, 'unitPrice': unitPrice}),
    );
    if (res.statusCode != 201) _throw(res);
    return ItemModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<void> deleteItem(String roomId, String itemId) async {
    final res = await _client.delete(
      Uri.parse('$_base/rooms/$roomId/items/$itemId'),
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
      Uri.parse('$_base/users/$userId/cart/$itemId'),
      headers: _headers,
      body: jsonEncode({'quantity': quantity}),
    );
    if (res.statusCode != 200) _throw(res);
  }

  static Future<void> removeFromCart(String userId, String itemId) async {
    final res = await _client.delete(
      Uri.parse('$_base/users/$userId/cart/$itemId'),
    );
    if (res.statusCode != 200) _throw(res);
  }

  // ── Session ───────────────────────────────────────────────────────────────

  /// Toggle confirmed state (admin only). Returns new isConfirmed value.
  static Future<bool> lockRoom(String roomId, String userId) async {
    final res = await _client.patch(
      Uri.parse('$_base/rooms/$roomId/confirm'),
      headers: _headers,
      body: jsonEncode({'userId': userId}),
    );
    if (res.statusCode != 200) _throw(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['isConfirmed'] as bool;
  }

  /// Save session summary to DB, clear all carts, unconfirm (admin only).
  static Future<void> newSession(String roomId, String userId) async {
    final res = await _client.post(
      Uri.parse('$_base/rooms/$roomId/new-session'),
      headers: _headers,
      body: jsonEncode({'userId': userId}),
    );
    if (res.statusCode != 200) _throw(res);
  }

  /// Returns the list of past session summaries for a room.
  static Future<List<Map<String, dynamic>>> getSessions(String roomId) async {
    final res = await _client.get(Uri.parse('$_base/rooms/$roomId/sessions'));
    if (res.statusCode != 200) _throw(res);
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  // ── Finance ───────────────────────────────────────────────────────────────

  /// Returns per-member balance summary (expenses, deposits, balance).
  static Future<List<Map<String, dynamic>>> getBalance(String roomId) async {
    final res = await _client.get(Uri.parse('$_base/rooms/$roomId/balance'));
    if (res.statusCode != 200) _throw(res);
    return (jsonDecode(res.body) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// Record a deposit for a member.
  static Future<void> addDeposit(
    String roomId,
    String userId,
    String targetUserId,
    double amount,
    String? note,
  ) async {
    final res = await _client.post(
      Uri.parse('$_base/rooms/$roomId/deposits'),
      headers: _headers,
      body: jsonEncode({
        'userId': userId,
        'targetUserId': targetUserId,
        'amount': amount,
        'note': note,
      }),
    );
    if (res.statusCode != 201) _throw(res);
  }

  /// Add a split expense — admin only. Splits among [memberIds] (or all active members if omitted).
  static Future<void> addSplitExpense(
    String roomId,
    String userId,
    String itemName,
    double totalAmount, {
    List<String>? memberIds,
  }) async {
    final res = await _client.post(
      Uri.parse('$_base/rooms/$roomId/split-expense'),
      headers: _headers,
      body: jsonEncode({
        'userId': userId,
        'itemName': itemName,
        'totalAmount': totalAmount,
        // ignore: use_null_aware_elements
        if (memberIds != null) 'memberIds': memberIds,
      }),
    );
    if (res.statusCode != 201) _throw(res);
  }

  /// Returns flat deposit + split-expense history for the room.
  static Future<Map<String, dynamic>> getFinanceHistory(String roomId) async {
    final res = await _client.get(
      Uri.parse('$_base/rooms/$roomId/finance-history'),
    );
    if (res.statusCode != 200) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Admin adds a member to the room by their username.
  static Future<Map<String, dynamic>> addMember(
    String roomId,
    String adminId,
    String username,
  ) async {
    final res = await _client.post(
      Uri.parse('$_base/rooms/$roomId/members'),
      headers: _headers,
      body: jsonEncode({'adminId': adminId, 'username': username}),
    );
    if (res.statusCode != 201) _throw(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// Admin deletes a deposit by ID.
  static Future<void> deleteDeposit(
    String roomId,
    String adminId,
    String depositId,
  ) async {
    final req = http.Request(
      'DELETE',
      Uri.parse('$_base/rooms/$roomId/deposits/$depositId'),
    );
    req.headers.addAll(_headers);
    req.body = jsonEncode({'adminId': adminId});
    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) _throw(res);
  }

  /// Admin deletes a split expense by ID.
  static Future<void> deleteSplitExpense(
    String roomId,
    String adminId,
    String expenseId,
  ) async {
    final req = http.Request(
      'DELETE',
      Uri.parse('$_base/rooms/$roomId/split-expenses/$expenseId'),
    );
    req.headers.addAll(_headers);
    req.body = jsonEncode({'adminId': adminId});
    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) _throw(res);
  }

  /// Admin deletes a session summary by ID.
  static Future<void> deleteSession(
    String roomId,
    String adminId,
    String sessionId,
  ) async {
    final req = http.Request(
      'DELETE',
      Uri.parse('$_base/rooms/$roomId/sessions/$sessionId'),
    );
    req.headers.addAll(_headers);
    req.body = jsonEncode({'adminId': adminId});
    final streamed = await _client.send(req);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) _throw(res);
  }
}
