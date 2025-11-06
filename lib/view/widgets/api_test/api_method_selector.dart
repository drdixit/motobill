import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ApiMethodSelector extends StatelessWidget {
  final String selectedMethod;
  final List<String> methods;
  final ValueChanged<String?> onChanged;

  const ApiMethodSelector({
    super.key,
    required this.selectedMethod,
    required this.methods,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: selectedMethod,
      decoration: InputDecoration(
        labelText: 'HTTP Method',
        prefixIcon: Icon(Icons.http, color: AppColors.primary),
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
      items: methods.map((String method) {
        return DropdownMenuItem<String>(value: method, child: Text(method));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
