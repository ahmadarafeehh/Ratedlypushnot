import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextFieldInput extends StatelessWidget {
  final TextEditingController textEditingController;
  final bool isPass;
  final String hintText;
  final TextInputType textInputType;
  final TextStyle? hintStyle;
  final Color? fillColor;
  final List<TextInputFormatter>? inputFormatters; // Add this line

  const TextFieldInput({
    Key? key,
    required this.textEditingController,
    this.isPass = false,
    required this.hintText,
    required this.textInputType,
    this.hintStyle,
    this.fillColor,
    this.inputFormatters, // Add this line
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: textEditingController,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: hintStyle,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      keyboardType: textInputType,
      obscureText: isPass,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Inter',
      ),
      inputFormatters: inputFormatters, // Add this line
    );
  }
}
