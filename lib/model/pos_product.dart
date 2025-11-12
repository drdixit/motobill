import 'package:flutter/material.dart';

class PosProduct {
  final int id;
  final String name;
  final String? partNumber;
  final String? description;
  final double sellingPrice;
  final double costPrice;
  final double? mrp;
  final String? imagePath;
  final String? hsnCode;
  final String? uqcCode;
  final String subCategoryName;
  final String mainCategoryName;
  final String manufacturerName;
  final bool isTaxable;
  final int hsnCodeId;
  final int uqcId;
  final int subCategoryId;
  final int manufacturerId;
  final double? cgstRate;
  final double? sgstRate;
  final double? igstRate;
  final double? utgstRate;
  final int stock;
  final int taxableStock;
  final int nonTaxableStock;
  final bool negativeAllow;
  final int min;
  final int max;

  PosProduct({
    required this.id,
    required this.name,
    this.partNumber,
    this.description,
    required this.sellingPrice,
    required this.costPrice,
    this.mrp,
    this.imagePath,
    this.hsnCode,
    this.uqcCode,
    required this.subCategoryName,
    required this.mainCategoryName,
    required this.manufacturerName,
    required this.isTaxable,
    required this.hsnCodeId,
    required this.uqcId,
    required this.subCategoryId,
    required this.manufacturerId,
    this.cgstRate,
    this.sgstRate,
    this.igstRate,
    this.utgstRate,
    required this.stock,
    required this.taxableStock,
    required this.nonTaxableStock,
    required this.negativeAllow,
    required this.min,
    required this.max,
  });

  factory PosProduct.fromJson(Map<String, dynamic> json) {
    return PosProduct(
      id: json['id'] as int,
      name: json['name'] as String,
      partNumber: json['part_number'] as String?,
      description: json['description'] as String?,
      sellingPrice: (json['selling_price'] as num).toDouble(),
      costPrice: (json['cost_price'] as num).toDouble(),
      mrp: json['mrp'] != null ? (json['mrp'] as num).toDouble() : null,
      imagePath: json['image_path'] as String?,
      hsnCode: json['hsn_code'] as String?,
      uqcCode: json['uqc_code'] as String?,
      subCategoryName: json['sub_category_name'] as String,
      mainCategoryName: json['main_category_name'] as String,
      manufacturerName: json['manufacturer_name'] as String,
      isTaxable: (json['is_taxable'] as int) == 1,
      hsnCodeId: json['hsn_code_id'] as int,
      uqcId: json['uqc_id'] as int,
      subCategoryId: json['sub_category_id'] as int,
      manufacturerId: json['manufacturer_id'] as int,
      cgstRate: json['cgst_rate'] != null
          ? (json['cgst_rate'] as num).toDouble()
          : null,
      sgstRate: json['sgst_rate'] != null
          ? (json['sgst_rate'] as num).toDouble()
          : null,
      igstRate: json['igst_rate'] != null
          ? (json['igst_rate'] as num).toDouble()
          : null,
      utgstRate: json['utgst_rate'] != null
          ? (json['utgst_rate'] as num).toDouble()
          : null,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      taxableStock: (json['taxable_stock'] as num?)?.toInt() ?? 0,
      nonTaxableStock: (json['non_taxable_stock'] as num?)?.toInt() ?? 0,
      negativeAllow: (json['negative_allow'] as int?) == 1,
      min: (json['min'] as int?) ?? 0,
      max: (json['max'] as int?) ?? 0,
    );
  }

  /// Get available stock based on bill type
  /// For taxable bills: only taxable stock
  /// For non-taxable bills: taxable + non-taxable stock (both can be used)
  int getAvailableStock({required bool isTaxableBill}) {
    if (isTaxableBill) {
      // Taxable bill: can only use taxable stock
      return taxableStock;
    } else {
      // Non-taxable bill: can use both taxable and non-taxable stock
      return taxableStock + nonTaxableStock;
    }
  }

  /// Get background color tint based on stock level vs min/max
  /// Returns null for normal background (no tint)
  /// Returns red tint if stock is below min
  /// Returns blue tint if stock is above max
  Color? getStockLevelColor() {
    // If both min and max are 0, no checking needed
    if (min == 0 && max == 0) {
      return null;
    }

    // Check min condition (if min is set)
    if (min > 0 && stock < min) {
      return Colors.red.withOpacity(0.4); // Darker red tint for low stock
    }

    // Check max condition (if max is set)
    if (max > 0 && stock > max) {
      return Colors.blue.withOpacity(0.4); // Darker blue tint for overstock
    }

    // Stock is within acceptable range or no limits set
    return null;
  }
}
