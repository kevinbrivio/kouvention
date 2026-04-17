import 'package:flutter/material.dart';

enum Flavor { staging, production }

Flavor convertToFlavorEnum(String value) {
  switch (value) {
    case 'production':
      return Flavor.production;
    default:
      return Flavor.staging;
  }
}

class FlavorValues {
  final bool showBanner;

  FlavorValues({required this.showBanner});
}

class FlavorConfig {
  final Flavor flavor;
  final String name;
  final FlavorValues values;
  static FlavorConfig? _instance;
  final Color color;

  static FlavorConfig? get instance => _instance;

  FlavorConfig._internal({
    required this.flavor,
    required this.name,
    required this.values,
    required this.color,
  });

  factory FlavorConfig({required Flavor flavor, required FlavorValues values}) {
    switch (flavor) {
      case Flavor.staging:
        _instance = FlavorConfig._internal(
          flavor: flavor,
          name: 'STAGING',
          values: values,
          color: Colors.orange,
        );
        break;
      case Flavor.production:
        _instance = FlavorConfig._internal(
          flavor: flavor,
          name: 'PRODUCTION',
          values: values,
          color: Colors.green,
        );
        break;
    }
    return _instance!;
  }

  static bool showBanner() => _instance!.values.showBanner;
}
