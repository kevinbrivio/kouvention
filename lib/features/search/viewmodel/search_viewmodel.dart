import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/features/auth/services/auth_service.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/chat/repositories/message_repository.dart';
import 'package:kouvention/features/chat/utils/display_name_resolver.dart';
import 'package:kouvention/features/search/models/search_result_group.dart';
import 'package:kouvention/features/search/models/search_result_model.dart';
import 'package:kouvention/features/search/services/local_search_service.dart';

enum SearchState { idle, searching, results, empty, error }

final searchVMProvider = ChangeNotifierProvider<SearchVM>((ref) {
  final searchService = ref.read(localSearchServiceProvider);
  final messageRepo = ref.read(messageRepositoryProvider);
  final currentUid = ref.read(authServiceProvider).currentUser?.uid;
  return SearchVM(searchService, messageRepo, currentUid!);
});

class SearchVM extends ChangeNotifier {
  final LocalSearchService _searchService;
  final MessageRepository _messageRepository;
  final String _currentUid;

  SearchVM(this._searchService, this._messageRepository, this._currentUid);

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
  void onTextChanged(
    String query,
    List<ChatModel> chatRooms,
    UserProfileResolver resolver,
  ) {
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
      _performSearch(query, chatRooms, resolver);
    });
  }

  Future<void> _performSearch(
    String query,
    List<ChatModel> chatRooms,
    UserProfileResolver resolver,
  ) async {
    _state = SearchState.searching;
    notifyListeners();

    try {
      debugPrint('------ SQLite Local SEARCHING WORKING -------');
      final sw = Stopwatch()..start();

      // Pass 1 — Contact filter via the fresh UserProfileResolver
      final lowerQuery = query.toLowerCase();
      _matchingContacts = chatRooms
          .where(
            (chat) => resolveDisplayName(
              chat: chat,
              currentUid: _currentUid,
              resolver: resolver,
            ).toLowerCase().contains(lowerQuery),
          )
          .toList();

      final t1 = sw.elapsedMilliseconds;
      debugPrint('🥷 Chat filtering (resolver): ${t1}ms');

      final contactResults = <SearchResultModel>[];
      for (final chat in _matchingContacts) {
        final recent = await _messageRepository.fetchRecentMessages(
          chat.id,
          limit: 20,
        );
        final chatName = resolveDisplayName(
          chat: chat,
          currentUid: _currentUid,
          resolver: resolver,
        );
        for (final msg in recent) {
          contactResults.add(SearchResultModel(
            messageId: msg.id,
            chatRoomId: msg.chatRoomId,
            chatName: chatName,
            senderId: msg.senderId,
            messageText: msg.textContent,
            senderName: msg.senderName,
            sentAt: DateTime.fromMillisecondsSinceEpoch(msg.sentAt),
            messageType: msg.type,
            mediaUrls: msg.mediaUrls,
            mimeType: msg.mimeType,
            fileName: msg.fileName,
            fileSizeBytes: msg.fileSizeBytes,
          ));
        }
      }
      final t1b = sw.elapsedMilliseconds;
      debugPrint('🥷 Contact messages: ${t1b - t1}ms');

      // Pass 2 — FTS5 text search (unchanged)
      final ftsResults = await _searchService.searchMessages(
        query: query,
        currentUid: _currentUid,
        chatRooms: chatRooms,
      );

      final t2 = sw.elapsedMilliseconds;
      debugPrint('🥷 FTS5 + mapping: ${t2 - t1b}ms');

      if (_query != query) return;

      // Union, dedup by (chatId, messageId), sort by sentAt DESC, cap at 50
      final seen = <String>{};
      final merged = <SearchResultModel>[
        ...ftsResults,
        ...contactResults,
      ];
      merged.retainWhere((r) => seen.add('${r.chatRoomId}:${r.messageId}'));
      merged.sort((a, b) => b.sentAt.compareTo(a.sentAt));
      final capped = merged.take(50).toList();

      // Resolve senderName for every result (FTS5 snapshots are stale)
      for (var i = 0; i < capped.length; i++) {
        final freshName = resolver.lookupDisplayName(capped[i].senderId);
        if (freshName != null) {
          capped[i] = capped[i].copyWith(senderName: freshName);
        }
      }

      debugPrint('🥷 Total: ${t2}ms | FTS5: ${ftsResults.length} | '
          'Contact: ${contactResults.length} | Merged: ${merged.length} | Capped: ${capped.length}');

      if (capped.isEmpty && _matchingContacts.isEmpty) {
        _state = SearchState.empty;
        _groups = [];
      } else {
        final resultChatMap = {for (final c in chatRooms) c.id: c};
        _groups = _groupResults(capped, resultChatMap, resolver);
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
    Map<String, ChatModel> chatMap,
    UserProfileResolver resolver,
  ) {
    final Map<String, List<SearchResultModel>> grouped = {};

    // Filter by chatRoomId
    for (final result in flatResults) {
      grouped.putIfAbsent(result.chatRoomId, () => []).add(result);
    }

    return grouped.entries.map((e) {
      final chat = chatMap[e.key];
      if (chat == null) {
        return SearchResultGroup(
          chatRoomId: e.key,
          chatDisplayName: 'Unknown',
          chatPhotoUrl: null,
          results: e.value..sort((a, b) => b.sentAt.compareTo(a.sentAt)),
        );
      }

      final displayName = resolveDisplayName(
        chat: chat,
        currentUid: _currentUid,
        resolver: resolver,
      );
      final photoUrl = resolveDisplayPhotoUrl(
        chat: chat,
        currentUid: _currentUid,
        resolver: resolver,
      );

      return SearchResultGroup(
        chatRoomId: e.key,
        chatDisplayName: displayName,
        chatPhotoUrl: photoUrl,
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
