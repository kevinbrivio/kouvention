import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kouvention/cores/bases/base_notifier.dart';
import 'package:kouvention/cores/constants/tokens.dart';
import 'package:kouvention/cores/widgets/loading_indicator.dart';

class BaseView<T extends BaseNotifier> extends ConsumerWidget {
  final AutoDisposeChangeNotifierProvider<T> provider;
  final Widget Function(BuildContext, T) builder;
  final Widget Function(BuildContext, T)? showOverlay;
  final PreferredSizeWidget Function(T)? appBar;
  final Color? backgroundColor;
  final bool useGradient;
  final DecorationImage? backgroundImage;

  const BaseView({
    super.key,
    required this.provider,
    required this.builder,
    this.showOverlay,
    this.appBar,
    this.backgroundColor,
    this.useGradient = true,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var viewmodel = ref.watch(provider);
    return _buildScreenContent(context, viewmodel);
  }

  Widget _buildScreenContent(BuildContext context, T viewmodel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Scaffold(
            extendBodyBehindAppBar: true,
            resizeToAvoidBottomInset: false,
            appBar: appBar != null ? appBar!(viewmodel) : null,
            backgroundColor: backgroundColor,
            body: (!viewmodel.isInitialized)
                ? const Center(child: LoadingIndicator())
                : Container(
                    decoration: useGradient
                        ? BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColorTokens.primaryDark,
                                AppColorTokens.primary,
                              ],
                              stops: const [0.1, 1.0],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          )
                        : BoxDecoration(
                            image: _buildBackgroundImage(
                              backgroundImage,
                              isDark,
                            ),
                            color: backgroundColor,
                          ),
                    child: Stack(
                      children: [
                        builder(context, viewmodel),
                        if (viewmodel.showOverlay && showOverlay != null)
                          showOverlay!(context, viewmodel),
                      ],
                    ),
                  ),
          ),
        ),

        if (viewmodel.isLoading &&
            !viewmodel.showOverlay &&
            viewmodel.isInitialized)
          const LoadingIndicator(showBackdrop: true),
      ],
    );
  }

  DecorationImage? _buildBackgroundImage(
    DecorationImage? original,
    bool isDark,
  ) {
    if (original == null) return null;
    if (!isDark) return original;
    return DecorationImage(
      image: original.image,
      fit: original.fit,
      alignment: original.alignment,
      repeat: original.repeat,
      matchTextDirection: original.matchTextDirection,
      colorFilter: const ColorFilter.mode(
        AppSurfaceDark.surfaceInputBar,
        BlendMode.multiply,
      ),
      onError: original.onError,
    );
  }
}
