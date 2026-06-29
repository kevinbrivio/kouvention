import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/services/chat_service.dart';
import 'package:kouvention/features/chat/services/databases/message_database.dart';
import 'package:kouvention/features/chat/viewmodel/recent_users_provider.dart';
import 'package:kouvention/features/user/models/user_model.dart';
import 'package:kouvention/features/user/services/user_service.dart';
import 'package:kouvention/cores/utils/log.dart';

final newChatVM = AutoDisposeChangeNotifierProvider<NewChatVM>(
  (ref) => NewChatVM(ref),
);

class NewChatVM extends BaseNotifier {
  final UserService _userService;
  final ChatService _chatService;
  final String? _currentUid;

  // Search
  StreamSubscription<List<UserSearchModel>>? _usersSubs;
  bool _isLoadingUsers = true;
  List<UserSearchModel> _allUsers = [];
  List<UserSearchModel> _searchResults = [];
  Timer? _debounceTimer;
  bool _isSearching = false;

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
  List<UserSearchModel> get allUsers => _allUsers;
  List<UserSearchModel> get searchResults => _searchResults;
  List<UserModel> get recentUsers =>
      ref.watch(recentUsersProvider).valueOrNull ?? [];
  List<UserModel> get selectedUsers => _selectedUsers;
  bool get isSearching => _isSearching;
  bool get isGroupMode => _isGroupMode;
  String? get error => _error;
  String? get currentUid => _currentUid;
  bool get hasSelection => _selectedUsers.isNotEmpty;
  bool get isLoadingUsers => _isLoadingUsers;

  @override
  FutureOr<void> init() async {
    _usersSubs = _userService.streamAllUser().listen(
      (users) {
        _allUsers = users.where((u) => u.uid != _currentUid).toList();
        _isLoadingUsers = false;
        notifyListeners();
      },
      onError: (e) {
        _allUsers = [];
        _isLoadingUsers = false;
        eLog('streamAllUser error: $e');
        notifyListeners();
      },
    );
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
      _error = null; // clear any stale error from a previous failed search
      notifyListeners();
      return;
    }

    _isSearching = true;
    _error = null; // clear previous error so the UI doesn't show it
    // while the new search is in flight
    notifyListeners();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim().toLowerCase();
  
    // 🔍 Cek 1: Apakah _allUsers sudah terisi?
    dLog('=== TOTAL allUsers: ${_allUsers.length}');
  
    // 🔍 Cek 2: Lihat isi _allUsers
    for (final u in _allUsers) {
      dLog('=== USER: ${u.displayName} | ${u.email}');
    }
  
    _searchResults = _allUsers
        .where((u) => u.uid != _currentUid)
        .where(
          (u) =>
              u.displayName.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q),
        )
        .toList();
  
    dLog('=== QUERY: $q');
    dLog('=== Hasil: $_searchResults');
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
      // Try Drift cache first; fall back to Firestore if missing (cold start).
      final db = ref.read(messageDatabaseProvider);
      final cached = await db.fetchProfileByIds({_currentUid});
      final profile = cached.firstOrNull;

      String? myDisplayName;
      String? myPhotoUrl;

      if (profile != null) {
        myDisplayName = profile.displayName;
        myPhotoUrl = profile.photoUrl;
      } else {
        final currentUser = await _userService.getUser(_currentUid);
        myDisplayName = currentUser?.displayName;
        myPhotoUrl = currentUser?.photoUrl;
      }

      if (myDisplayName == null) return null;

      final memberInfo = {
        _currentUid: MemberInfo(
          displayName: myDisplayName,
          photoUrl: myPhotoUrl,
        ),
        otherUser.uid: MemberInfo(
          displayName: otherUser.displayName,
          photoUrl: otherUser.photoUrl,
        ),
      };

      final chatId = await _chatService.createDirectChat(
        currentUid: _currentUid,
        otherUid: otherUser.uid,
        memberInfo: memberInfo,
      );

      return chatId;
    } catch (e) {
      _error = 'Failed to create chat';
      eLog('Create chat error: $e');
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
      // Try Drift cache first; fall back to Firestore if missing (cold start).
      final db = ref.read(messageDatabaseProvider);
      final cached = await db.fetchProfileByIds({_currentUid});
      final profile = cached.firstOrNull;

      String? myDisplayName;
      String? myPhotoUrl;

      if (profile != null) {
        myDisplayName = profile.displayName;
        myPhotoUrl = profile.photoUrl;
      } else {
        final currentUser = await _userService.getUser(_currentUid);
        myDisplayName = currentUser?.displayName;
        myPhotoUrl = currentUser?.photoUrl;
      }

      if (myDisplayName == null) return null;

      final allMembers = [_currentUid, ..._selectedUsers.map((u) => u.uid)];

      final memberInfo = <String, MemberInfo>{
        _currentUid: MemberInfo(
          displayName: myDisplayName,
          photoUrl: myPhotoUrl,
        ),
        for (final user in _selectedUsers)
          user.uid: MemberInfo(
            displayName: user.displayName,
            photoUrl: user.photoUrl,
          ),
      };

      final chatId = await _chatService.createGroupChat(
        createdByUid: _currentUid,
        createdByName: myDisplayName,
        members: allMembers,
        memberInfo: memberInfo,
        groupName: groupName,
      );

      return chatId;
    } catch (e) {
      _error = 'Failed to create group';
      eLog('Create group error: $e');
      notifyListeners();
      return null;
    }
  }

  // ── Cleanup ─────────────────────────────────────────

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usersSubs?.cancel();
    super.dispose();
  }
}
