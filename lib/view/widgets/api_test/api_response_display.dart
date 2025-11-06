import 'package:flutter/material.dart';

class ApiResponseDisplay extends StatelessWidget {
  final String requestInfo;
  final String responseInfo;

  const ApiResponseDisplay({
    super.key,
    required this.requestInfo,
    required this.responseInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            requestInfo + responseInfo,
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
          ),
        ),
      ),
    );
  }
}
