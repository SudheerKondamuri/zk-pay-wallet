import 'package:flutter/material.dart';
import '../../core/theme.dart';


/// Text input with Verdigris styling and optional suffix icon.
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final Key? fieldKey;

  const AppTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.onChanged,
    this.enabled = true,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      enabled: enabled,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontFamily: 'SpaceGrotesk',
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        errorText: errorText,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
        errorStyle: TextStyle(
          color: AppColors.danger,
          fontSize: 12,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
