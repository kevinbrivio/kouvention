import 'package:flutter/cupertino.dart';

class CustomSlider extends StatefulWidget {
  final Function(int) onChanged;

  const CustomSlider({super.key, required this.onChanged});

  @override
  State<CustomSlider> createState() => _CustomSliderState();
}

class _CustomSliderState extends State<CustomSlider> {
  int _currentPage = 0;

  List<String> imageUrls = [];
  
  void _onSwipe(bool toLeft) {
    setState(() {
      if (toLeft && _currentPage < imageUrls.length - 1) {
        _currentPage++;
      } else if (!toLeft && _currentPage > 0) {
        _currentPage--;
      }
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragEnd: (details) {
      if (details.primaryVelocity != null) {
        _onSwipe(details.primaryVelocity! < 0);
      }
    },
    child: SizedBox(
      
    ),
  );
}
