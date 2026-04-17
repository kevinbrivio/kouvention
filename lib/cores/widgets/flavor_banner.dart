import 'package:flutter/material.dart';
import 'package:kouvention/cores/configs/flavor_config.dart';

class FlavorBanner extends StatefulWidget {
  final Widget child;
  final double bannerWidth;
  final double bannerHeight;
  final BannerLocation bannerLocation;
  final bool? showBanner;

  const FlavorBanner({
    super.key,
    required this.child,
    this.bannerWidth = 35,
    this.bannerHeight = 55,
    this.bannerLocation = BannerLocation.topStart,
    this.showBanner,
  });

  @override
  State<FlavorBanner> createState() => _FlavorBannerState();
}

class _FlavorBannerState extends State<FlavorBanner> {
  BannerConfig? bannerConfig;

  @override
  Widget build(BuildContext context) {
    // Use the widget's showBanner property if provided, otherwise fallback to
    // FlavorConfig
    if (widget.showBanner == false ||
        (!FlavorConfig.showBanner() && widget.showBanner == null)) {
      return widget.child;
    }
    bannerConfig ??= _getDefaultBanner();
    return Stack(
      children: <Widget>[
        widget.child,
        _buildBanner(context),
      ],
    );
  }

  BannerConfig _getDefaultBanner() => BannerConfig(
        bannerName: FlavorConfig.instance!.name,
        bannerColor: FlavorConfig.instance!.color,
      );

  Widget _buildBanner(BuildContext context) => SizedBox(
        width: widget.bannerWidth,
        height: widget.bannerHeight,
        child: CustomPaint(
          painter: BannerPainter(
            message: bannerConfig!.bannerName,
            textDirection: Directionality.of(context),
            layoutDirection: Directionality.of(context),
            location: widget.bannerLocation,
            color: bannerConfig!.bannerColor,
          ),
        ),
      );
}

class BannerConfig {
  final String bannerName;
  final Color bannerColor;

  BannerConfig({required this.bannerName, required this.bannerColor});
}
