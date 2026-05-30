import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/search/models/search_result_group.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/services/local_search_service.dart';
import 'package:kouvention/features/shared/services/sync_service.dart';

enum SearchState { idle, searching, results, empty, error }

final searchVMProvider = ChangeNotifierProvider.autoDispose<SearchVM>((ref) {
  final searchService = ref.read(localSearchServiceProvider);
  final syncService = ref.read(syncServiceProvider);
  final currentUid = ref.read(authServiceProvider).currentUser?.uid;
  return SearchVM(searchService, syncService, currentUid!);
});

class SearchVM extends ChangeNotifier {
  final LocalSearchService _searchService;
  final SyncService _syncService;
  final String _currentUid;

  SearchVM(this._searchService, this._syncService, this._currentUid);

  // --- State -----
  SearchState _state = SearchState.idle;
  String _query = '';
  List<SearchResultGroup> _groups = [];
  String? _error;
  Timer? _debouncer;
  bool _isActive = false;
  List<ChatModel> _matchingContacts = [];

  // --- Getter -----
  SearchState get state => _state;
  String get query => _query;
  List<SearchResultGroup> get groups => _groups;
  String? get error => _error;
  Timer? get debouncer => _debouncer;
  bool get isActive => _isActive;
  List<ChatModel> get matchingContacts => _matchingContacts;
  String get currentUid => _currentUid;

  // Called on every keystroke hit in TextField
  void onTextChanged(String query, List<ChatModel> chatRooms) {
    _query = query;

    // if user cleared the search bar
    if (query.trim().isEmpty) {
      _state = SearchState.idle;
      _query = '';
      _groups = [];
      _matchingContacts = [];
      _debouncer?.cancel();
      _searchService.cancelSearch();

      notifyListeners();
      return;
    }

    // Cancel previous search
    _searchService.cancelSearch();

    // Fires debouncer
    _debouncer?.cancel(); // reset
    _debouncer = Timer(Duration(milliseconds: 400), () {
      _performSearch(query, chatRooms);
    });
  }

  Future<void> _performSearch(String query, List<ChatModel> chatRooms) async {
    _state = SearchState.searching;
    notifyListeners();

    try {
      debugPrint('------ SQLite Local SEARCHING WORKING -------');
      final sw = Stopwatch()..start();

      final lowerQuery = query.toLowerCase();
      _matchingContacts = chatRooms
          .where(
            (chat) => chat
                .displayName(_currentUid)
                .toLowerCase()
                .contains(lowerQuery),
          )
          .toList();

      final t1 = sw.elapsedMilliseconds;
      debugPrint('🥷 Chat filtering: ${t1}ms');

      final results = await _searchService.searchMessages(
        query: query,
        currentUid: _currentUid,
        chatRooms: chatRooms,
      );

      final t2 = sw.elapsedMilliseconds;
      debugPrint('🥷 SQL + mapping: ${t2 - t1}ms');
      debugPrint('🥷 Total: ${t2}ms | Results: ${results.length}');

      if (_query != query) return;

      if (results.isEmpty && _matchingContacts.isEmpty) {
        _state = SearchState.empty;
        _groups = [];
      } else {
        _groups = _groupResults(results, chatRooms);
        _state = SearchState.results;
      }
    } catch (e) {
      if (_query != query) return;
      _error = e.toString();
      _state = SearchState.empty;
    }

    notifyListeners();
  }

  List<SearchResultGroup> _groupResults(
    List<SearchResultModel> flatResults,
    List<ChatModel> chatRooms,
  ) {
    final Map<String, List<SearchResultModel>> grouped = {};

    // Filter by chatRoomId
    for (final result in flatResults) {
      grouped.putIfAbsent(result.chatRoomId, () => []).add(result);
    }

    return grouped.entries.map((e) {
      final chat = chatRooms.firstWhere((c) => c.id == e.key);

      return SearchResultGroup(
        chatRoomId: e.key,
        chatDisplayName: chat.displayName(_currentUid),
        chatPhotoUrl: chat.displayPhotoUrl(_currentUid),
        results: e.value..sort((a, b) => b.sentAt.compareTo(a.sentAt)),
      );
    }).toList();
  }

  void openSearch(List<ChatModel> chatRooms) {
    _isActive = true;
    _state = SearchState.idle;
    notifyListeners();
  }

  void clearSearch() {
    _isActive = false;
    _debouncer?.cancel();
    _searchService.cancelSearch();
    _query = '';
    _groups = [];
    _error = null;
    _state = SearchState.idle;
    _matchingContacts.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _isActive = false;
    _debouncer?.cancel();
    _searchService.dispose();
    super.dispose();
  }
}
