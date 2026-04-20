import 'package:flutter/material.dart';

class TextInputModel {
  final controller = TextEditingController();
  String? Function(String)? validator;

  // Getter
  String get text => controller.text.trim();
  String get untrimmedText => controller.text;
  String get textWithNoComma => controller.text.replaceAll(',', '');

  // Setter
  set text(String value) => controller.text = value;

  // Clear form
  void clear() => controller.clear();

  TextInputModel({this.validator});
}

extension TextInputModelFactory on TextInputModel {
  static TextInputModel fromText(String text, {String? Function(String)? validator}) {
    final model = TextInputModel(validator: validator);
    model.text = text;
    return model;
  }
}