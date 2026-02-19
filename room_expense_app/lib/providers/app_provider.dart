import 'package:flutter/foundation.dart';

import '../models/cart_item_model.dart';
import '../models/room_model.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  UserModel? _currentUser;
  RoomModel? _currentRoom;
  List<RoomModel> _userRooms = [];

  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  RoomModel? get currentRoom => _currentRoom;
  List<RoomModel> get userRooms => List.unmodifiable(_userRooms);
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ─── Refresh room from server ───────────────────────────────────────────────
  Future<void> _refreshRoom() async {
    if (_currentRoom == null) return;
    _currentRoom = await ApiService.getRoom(_currentRoom!.id);
    if (_currentUser != null) {
      final updated = _currentRoom!.members[_currentUser!.id];
      if (updated != null) {
        _currentUser!.cart
          ..clear()
          ..addAll(updated.cart);
      }
    }
    notifyListeners();
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<void> signup(String username, String name, String password) async {
    _setLoading(true);
    try {
      _currentUser = await ApiService.signup(username.trim(), name.trim(), password);
      _userRooms = [];
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> login(String username, String password) async {
    _setLoading(true);
    try {
      _currentUser = await ApiService.login(username.trim(), password);
      _userRooms = await ApiService.getUserRooms(_currentUser!.id);
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
    _currentUser = null;
    _currentRoom = null;
    _userRooms = [];
    notifyListeners();
  }

  // ─── Rooms ─────────────────────────────────────────────────────────────────

  Future<void> loadUserRooms() async {
    if (_currentUser == null) return;
    try {
      _userRooms = await ApiService.getUserRooms(_currentUser!.id);
      notifyListeners();
    } catch (_) {}
  }

  Future<RoomModel> createRoom(String name) async {
    _setLoading(true);
    try {
      final room = await ApiService.createRoom(name.trim(), _currentUser!.id);
      _currentRoom = room;
      await loadUserRooms();
      notifyListeners();
      return room;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> joinRoom(String code) async {
    _setLoading(true);
    try {
      final room = await ApiService.joinRoom(
        code.trim().toUpperCase(),
        _currentUser!.id,
      );
      _currentRoom = room;
      await loadUserRooms();
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> openRoom(String roomId) async {
    _setLoading(true);
    try {
      _currentRoom = await ApiService.getRoom(roomId);
      if (_currentUser != null) {
        final updated = _currentRoom!.members[_currentUser!.id];
        if (updated != null) {
          _currentUser!.cart
            ..clear()
            ..addAll(updated.cart);
        }
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void clearRoom() {
    _currentRoom = null;
    notifyListeners();
  }

  Future<void> leaveRoom() async {
    _setLoading(true);
    try {
      await ApiService.leaveRoom(_currentRoom!.id, _currentUser!.id);
      _currentRoom = null;
      await loadUserRooms();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteRoom() async {
    _setLoading(true);
    try {
      await ApiService.deleteRoom(_currentRoom!.id, _currentUser!.id);
      _currentRoom = null;
      await loadUserRooms();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Items ─────────────────────────────────────────────────────────────────

  Future<void> addItem(String name, double unitPrice) async {
    _setLoading(true);
    try {
      await ApiService.addItem(_currentRoom!.id, name.trim(), unitPrice);
      await _refreshRoom();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteItem(String itemId) async {
    _setLoading(true);
    try {
      await ApiService.deleteItem(_currentRoom!.id, itemId);
      await _refreshRoom();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ─── Cart ──────────────────────────────────────────────────────────────────

  Future<void> addToCart(String itemId, int quantity) async {
    final room = _currentRoom!;
    final user = _currentUser!;
    if (quantity <= 0) {
      user.cart.remove(itemId);
    } else {
      final item = room.items[itemId]!;
      user.cart[itemId] =
          (user.cart[itemId]?..quantity = quantity) ??
          CartItemModel(item: item, quantity: quantity);
    }
    notifyListeners();

    try {
      await ApiService.updateCart(user.id, itemId, quantity);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      await _refreshRoom();
    }
  }

  Future<void> removeFromCart(String itemId) async {
    _currentUser!.cart.remove(itemId);
    notifyListeners();
    try {
      await ApiService.removeFromCart(_currentUser!.id, itemId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      await _refreshRoom();
    }
  }

  int cartQuantityOf(String itemId) {
    return _currentUser!.cart[itemId]?.quantity ?? 0;
  }

  // Poll room data (call from RoomScreen when tab changes to Summary)
  Future<void> refreshRoom() async {
    try {
      await _refreshRoom();
    } catch (_) {}
  }
}
