import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';

final newChatVM = AutoDisposeChangeNotifierProvider<NewChatVM>(
  (ref) => NewChatVM(ref),
);

class NewChatVM extends BaseNotifier {
  final UserService _userService;
  final ChatService _chatService;
  final String? _currentUid;

  // Search
  List<UserModel> _searchResults = [];
  Timer? _debounceTimer;
  bool _isSearching = false;

  // Recent List
  List<UserModel> _recentUsers = [];

  // Group chat selection
  final List<UserModel> _selectedUsers = [];
  bool _isGroupMode = false;

  // Error
  String? _error;

  NewChatVM(super.ref)
    : _userService = ref.read(userServiceProvider),
      _chatService = ref.read(chatServiceProvider),
      _currentUid = ref.read(authServiceProvider).currentUser?.uid;

  // ── Getters ─────────────────────────────────────────

  List<UserModel> get searchResults => _searchResults;
  List<UserModel> get recentUsers => _recentUsers;
  List<UserModel> get selectedUsers => _selectedUsers;
  bool get isSearching => _isSearching;
  bool get isGroupMode => _isGroupMode;
  String? get error => _error;
  String? get currentUid => _currentUid;
  bool get hasSelection => _selectedUsers.isNotEmpty;

  @override
  FutureOr<void> init() async {
    if (_currentUid != null) {
      await _loadRecentUsers();
    }
  }

  // ── Search ─────────────────────────────────────────
  /// Called on every keystroke in the search field.
  /// Debounces 400ms to avoid hammering Firestore on fast typing.
  ///
  /// Why 400ms? Too short (100ms) still fires on every word.
  /// Too long (1s) feels unresponsive. 400ms catches the pause
  /// between keystrokes without feeling laggy.
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

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (_currentUid == null) return;

    try {
      _searchResults = await _userService.searchUsers(
        query: query,
        currentUid: _currentUid!,
      );
      _error = null;
    } catch (e) {
      _error = 'Search failed';
      debugPrint('Search error: $e');
    }

    _isSearching = false;
    notifyListeners();
  }

  // ── Recent Users ──────────────────────────────────────
  /// Get the recent users from latest chats
  Future<void> _loadRecentUsers() async {
    if (_currentUid == null) return;

    try {
      final chats = await _chatService.streamChatList(_currentUid).first;
      _error = null;

      // Get other users with 'direct' type of chat
      final otherUids = chats
          .where((chat) => chat.type == 'direct')
          .map((chat) => chat.otherMemberUid(_currentUid))
          .toList();

      final users = <UserModel>[];
      for (final uid in otherUids) {
        final user = await _userService.getUser(uid);
        if (user != null) users.add(user);
      }

      _recentUsers = users;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch latest users');
    }

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

  // ── Create Chat ─────────────────────────────────────
  /// Creates a direct chat with the tapped user.
  /// Returns the chat ID to navigate to.
  ///
  /// Under the hood, createDirectChat checks memberHash first —
  /// if a chat already exists between these two users, it returns
  /// the existing ID instead of creating a duplicate.
  Future<String?> createDirectChat(UserModel otherUser) async {
    if (_currentUid == null) return null;

    try {
      final currentUser = await _userService.getUser(_currentUid!);
      if (currentUser == null) return null;

      final memberInfo = {
        _currentUid!: MemberInfo(
          displayName: currentUser.displayName,
          photoUrl: currentUser.photoUrl,
        ),
        otherUser.uid: MemberInfo(
          displayName: otherUser.displayName,
          photoUrl: otherUser.photoUrl,
        ),
      };

      final chatId = await _chatService.createDirectChat(
        currentUid: _currentUid!,
        otherUid: otherUser.uid,
        memberInfo: memberInfo,
      );

      return chatId;
    } catch (e) {
      _error = 'Failed to create chat';
      debugPrint('Create chat error: $e');
      notifyListeners();
      return null;
    }
  }

  /// Creates a group chat with all selected users.
  /// Returns the chat ID to navigate to.
  ///
  /// No duplicate check here — it's valid to have multiple groups
  /// with the same members (e.g. "Project A" and "Project B").
  Future<String?> createGroupChat(String groupName) async {
    if (_currentUid == null || _selectedUsers.isEmpty) return null;

    try {
      final currentUser = await _userService.getUser(_currentUid!);
      if (currentUser == null) return null;

      final allMembers = [_currentUid!, ..._selectedUsers.map((u) => u.uid)];

      final memberInfo = <String, MemberInfo>{
        _currentUid!: MemberInfo(
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
        createdBy: _currentUid!,
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
