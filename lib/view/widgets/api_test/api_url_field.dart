import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ApiUrlField extends StatelessWidget {
  final TextEditingController controller;

  const ApiUrlField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'API URL',
        hintText: 'Enter API endpoint URL',
        prefixIcon: Icon(Icons.link, color: AppColors.primary),
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
    );
  }
}
