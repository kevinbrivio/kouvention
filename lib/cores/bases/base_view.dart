import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';

class BaseView<T extends BaseNotifier> extends ConsumerWidget {
  final AutoDisposeChangeNotifierProvider<T> provider;
  final Widget Function(BuildContext, T) builder;
  final Widget Function(BuildContext, T)? showOverlay;
  final PreferredSizeWidget Function(T)? appBar;
  final Color? backgroundColor;

  BaseView({
    super.key,
    required this.provider,
    required this.builder,
    this.showOverlay,
    this.appBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var viewmodel = ref.watch(provider);
    return _buildScreenContent(context, viewmodel);
  }

  Widget _buildScreenContent(BuildContext context, T viewmodel) => Stack(
    children: [
      GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          appBar: appBar != null ? appBar!(viewmodel) : null,
          backgroundColor: backgroundColor,
          body: (!viewmodel.isInitialized)
              ? const Center(child:LoadingIndicator())
              : Stack(
                  children: [
                    builder(context, viewmodel),
                    if (viewmodel.showOverlay && showOverlay != null)
                      showOverlay!(context, viewmodel),
                  ],
                ),
        ),
      ),

      if (viewmodel.isLoading &&
        !viewmodel.showOverlay &&
        viewmodel.isInitialized) const LoadingIndicator(showBackdrop: true,),
    ],
  );
}
