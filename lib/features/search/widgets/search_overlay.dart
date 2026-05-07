import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/cores/constants/text_theme.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';
import 'package:kouvention/features/search/viewmodel/search_viewmodel.dart';
import 'package:kouvention/features/search/widgets/search_body.dart';

class SearchOverlay extends StatefulWidget {
  final SearchVM searchVm;
  final ChatListVM chatVm;

  const SearchOverlay({
    super.key,
    required this.searchVm,
    required this.chatVm,
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  late final TextEditingController _controller;

  // Access VMs through widget — available everywhere, no ref needed
  SearchVM get _searchVm => widget.searchVm;
  ChatListVM get _chatVm => widget.chatVm;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    Future(() => _searchVm.openSearch()); // ← no ref, no problem
  }

  @override
  void dispose() {
    _controller.dispose();
    Future(() => _searchVm.clearSearch()); // ← no ref, no problem
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _searchVm,
    builder: (context, _) => DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          _buildDragHandle(),
          _buildSearchBar(),
          Expanded(child: searchBody(context, _searchVm)),
        ],
      ),
    ),
  );

  Widget _buildDragHandle() => Center(
    child: Container(
      margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2.r),
      ),
    ),
  );

  Widget _buildSearchBar() => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
    child: Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back, size: 20.sp, color: AppColors.grey),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              border: BoxBorder.all(color: AppColors.primary, width: 2.w),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (query) =>
                  _searchVm.onTextChanged(query, _chatVm.chats),
              decoration: InputDecoration(
                hintText: 'Search messages...',
                hintStyle: textTheme.subDescription3,
                border: InputBorder.none,
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _searchVm.onTextChanged('', _chatVm.chats);
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
