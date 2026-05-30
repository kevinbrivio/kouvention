import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/features/chat/models/chat_model.dart';
import 'package:kouvention/features/search/widgets/search_body.dart';

class SearchOverlay extends StatefulWidget {
  final List<ChatModel> chats;
  final Function(String) onSearchChanged;
  final Function onOpenSearch;

  const SearchOverlay({
    super.key,
    required this.onOpenSearch,
    required this.onSearchChanged,
    required this.chats,
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  late final TextEditingController _controller;
  String _text = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: true,
    onPopInvokedWithResult: (didPop, _) {
      widget.onSearchChanged('');
      _controller.clear();
    },
    child: DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          _buildDragHandle(),
          _buildSearchBar(),
          Expanded(child: SearchBody()),
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
          onPressed: () {
            widget.onSearchChanged('');
            _controller.clear();
            Navigator.of(context).pop();
          },
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: AppColors.primary, width: 2.w),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: TextField(
              onChanged: (query) {
                setState(() => _text = query);
                widget.onSearchChanged(query);
              },
              controller: _controller,
              decoration: InputDecoration(
                suffixIcon: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => _controller.text.isEmpty
                      ? SizedBox.shrink()
                      : IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () {
                            setState(() => _text = '');
                            _controller.clear();
                            widget.onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
