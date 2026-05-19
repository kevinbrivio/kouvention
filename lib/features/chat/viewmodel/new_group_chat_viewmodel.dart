import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/viewmodel/recent_users_provider.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

final newGroupChatVM = AutoDisposeChangeNotifierProvider<NewGroupChatVM>(
  (ref) => NewGroupChatVM(ref),
);

class NewGroupChatVM extends BaseNotifier {
  final UserService _userService;
  final ChatService _chatService;
  final String? _currentUid;

  // Search
  List<UserModel> _searchResults = [];
  Timer? _debounceTimer;
  bool _isSearching = false;

  // Recent Users
  List<UserModel> _recentUsers = [];

  // Group chat selection
  final List<UserModel> _selectedUsers = [];
  bool _isGroupMode = false;

  // Error
  String? _error;

  NewGroupChatVM(super.ref)
    : _userService = ref.read(userServiceProvider),
      _chatService = ref.read(chatServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  // ── Getters ─────────────────────────────────────────
  List<UserModel> get searchResults => _searchResults;
  List<UserModel> get recentUsers =>
      ref.watch(recentUsersProvider).valueOrNull ?? [];
  List<UserModel> get selectedUsers => _selectedUsers;
  bool get isSearching => _isSearching;
  String? get error => _error;
  String? get currentUid => _currentUid;
  bool get hasSelection => _selectedUsers.isNotEmpty;

  @override
  FutureOr<void> init() {}

  // ── Search ──────────────────────────────────────────

  /// Called on every keystroke in the search field.
  /// Debounces 400ms to avoid hammering Firestore on fast typing.
  void onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (_currentUid == null) return;

    try {
      _searchResults = await _userService.searchUsers(
        query: query,
        currentUid: _currentUid,
      );
      _error = null;
    } catch (e) {
      _error = 'Search failed';
      debugPrint('Search error: $e');
    }

    _isSearching = false;
    notifyListeners();
  }

  // ── Group Mode ──────────────────────────────────────

  void toggleGroupMode() {
    _isGroupMode = !_isGroupMode;
    if (!_isGroupMode) {
      _selectedUsers.clear(); // Reset selection when leaving group mode
    }
    notifyListeners();
  }

  void toggleUserSelection(UserModel user) {
    final index = _selectedUsers.indexWhere((u) => u.uid == user.uid);
    if (index >= 0) {
      _selectedUsers.removeAt(index);
    } else {
      _selectedUsers.add(user);
    }
    notifyListeners();
  }

  bool isUserSelected(UserModel user) {
    return _selectedUsers.any((u) => u.uid == user.uid);
  }

  /// Creates a group chat with all selected users.
  /// Returns the chat ID to navigate to.
  ///
  /// No duplicate check here — it's valid to have multiple groups
  /// with the same members (e.g. "Project A" and "Project B").
  Future<String?> createGroupChat(String groupName) async {
    if (_currentUid == null || _selectedUsers.isEmpty) return null;

    try {
      final currentUser = await _userService.getUser(_currentUid);
      if (currentUser == null) return null;

      final allMembers = [_currentUid, ..._selectedUsers.map((u) => u.uid)];

      final memberInfo = <String, MemberInfo>{
        _currentUid: MemberInfo(
          displayName: currentUser.displayName,
          photoUrl: currentUser.photoUrl,
        ),
        for (final user in _selectedUsers)
          user.uid: MemberInfo(
            displayName: user.displayName,
            photoUrl: user.photoUrl,
          ),
      };

      final chatId = await _chatService.createGroupChat(
        createdByUid: _currentUid,
        createdByName: currentUser.displayName,
        members: allMembers,
        memberInfo: memberInfo,
        groupName: groupName,
      );

      return chatId;
    } catch (e) {
      _error = 'Failed to create group';
      debugPrint('Create group error: $e');
      notifyListeners();
      return null;
    }
  }

  // ── Cleanup ─────────────────────────────────────────

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
