import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';
import 'package:kouvention/features/shared/viewmodel/connectivity_viewmodel.dart';

class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return connectivity.when(
      data: (isConnected) {
        if (isConnected) return const SizedBox.shrink();

        // No Connection -> Show banner
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16.r),
          ),
          padding: EdgeInsets.all(8.w),
          child: const Text(
            'No internet connection',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        );
      },
      error: (_, __) => const SizedBox.shrink(),
      loading: () => const LoadingIndicator(),
    );
  }
}
