import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ApiUrlField extends StatelessWidget {
  final TextEditingController controller;

  const ApiUrlField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'API URL',
          prefixIcon: Icon(Icons.link, color: AppColors.primary, size: 20),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
