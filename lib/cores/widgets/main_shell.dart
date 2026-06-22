import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/features/search/viewmodel/search_viewmodel.dart';

class MainShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  Widget build(BuildContext context) {
    final searchVM = ref.read(searchVMProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: widget.navigationShell,
      bottomNavigationBar: searchVM.isActive
          ? null
          : _buildFloatingNav(context),
    );
  }

  Widget _buildFloatingNav(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenH.w,
        right: AppSpacing.screenH.w,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xxs.h,
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
            _CustomNavItem(
              icon: Icons.chat_bubble_rounded,
              label: 'Chats',
              isSelected: currentIndex == 0,
              onTap: () => widget.navigationShell.goBranch(0),
            ),
            _CustomNavItem(
              icon: Icons.auto_stories_outlined,
              label: 'Updates',
              isSelected: currentIndex == 1,
              onTap: () => widget.navigationShell.goBranch(1),
            ),
            _CustomNavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              isSelected: currentIndex == 2,
              onTap: () => widget.navigationShell.goBranch(2),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CustomNavItem> createState() => _CustomNavItemState();
}

class _CustomNavItemState extends State<_CustomNavItem> {
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapUp: (_) => widget.onTap(),
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: EdgeInsets.all(AppSpacing.xxs.w),
      child:
          Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: AppSizing.iconMd.r,
                    color: widget.isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  Gap(4.h),
                  Text(
                    widget.label,
                    style: context.text.labelSmall.copyWith(
                      color: widget.isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: widget.isSelected
                          ? FontWeight.w400
                          : FontWeight.w300,
                    ),
                  ),
                ],
              )
              .animate(target: widget.isSelected ? 1 : 0)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1, 1),
                duration: 300.ms,
                curve: Curves.easeOutBack,
              )
              .shimmer(angle: 1.57, size: 2, duration: 400.ms)
              .flipV(curve: Curves.easeInOutCubic, duration: 400.ms, end: 0.1)
              .scaleXY(end: 1, alignment: const Alignment(0, 0.1)),
    ),
  );
}
