import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/colors.dart';
import 'package:kouvention/features/chat/viewmodel/chat_list_viewmodel.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {

  @override
  Widget build(BuildContext context) {
    // Keep the realtime sync alive for the entire authenticated session
    ref.watch(realtimeChatSyncProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: widget.navigationShell,
      bottomNavigationBar: _buildFloatingNav(context),
    );
  }

  Widget _buildFloatingNav(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    return Padding(
      padding: EdgeInsets.only(
        left: 60.w,
        right: 60.w,
        bottom: MediaQuery.of(context).padding.bottom + 16.h,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(48.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              icon: Icons.chat_bubble_rounded,
              label: 'Chats',
              isSelected: currentIndex == 0,
              onTap: () => widget.navigationShell.goBranch(0),
            ),
            _buildNavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              isSelected: currentIndex == 1,
              onTap: () => widget.navigationShell.goBranch(1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) => Padding(
    padding: EdgeInsets.all(4.w),
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(48.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: isSelected ? AppColors.primary : AppColors.grey,
            ),
            Gap(6.w),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.grey,
                fontSize: 8.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
