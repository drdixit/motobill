import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../model/pos_product.dart';

class PosProductCard extends StatelessWidget {
  final PosProduct product;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;
  final int cartQuantity;

  const PosProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onSecondaryTap,
    this.cartQuantity = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onSecondaryTap: onSecondaryTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image (Top)
                  Expanded(child: Center(child: _buildProductImage())),
                  const SizedBox(height: AppSizes.paddingS),

                  // Product Name and Part Number with Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: AppSizes.fontM,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Part Number and Price Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Part Number
                          if (product.partNumber != null)
                            Expanded(
                              child: Text(
                                product.partNumber!,
                                style: TextStyle(
                                  fontSize: AppSizes.fontS,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          // Price (with tax for taxable products)
                          Text(
                            _getPriceText(),
                            style: TextStyle(
                              fontSize: AppSizes.fontM,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Stock Text (left side of image)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: product.negativeAllow
                        ? Colors.red.shade300
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      // Total stock
                      TextSpan(
                        text: '${product.stock}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: product.negativeAllow
                              ? Colors.red.shade900
                              : Colors.black,
                        ),
                      ),
                      // Opening parenthesis
                      TextSpan(
                        text: ' (',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      // Taxable stock (green)
                      TextSpan(
                        text: '${product.taxableStock}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                      // Slash separator
                      TextSpan(
                        text: '/',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      // Non-taxable stock (orange)
                      TextSpan(
                        text: '${product.nonTaxableStock}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      // Closing parenthesis
                      TextSpan(
                        text: ')',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Quantity Badge
            if (cartQuantity > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '$cartQuantity',
                    style: TextStyle(
                      fontSize: AppSizes.fontS,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getPriceText() {
    if (product.isTaxable) {
      // Calculate price with tax (CGST + SGST + UTGST)
      final cgstRate = product.cgstRate ?? 0.0;
      final sgstRate = product.sgstRate ?? 0.0;
      final utgstRate = product.utgstRate ?? 0.0;
      final totalTaxRate = cgstRate + sgstRate + utgstRate;
      final priceWithTax = product.sellingPrice * (1 + totalTaxRate / 100);
      return '₹${priceWithTax.toStringAsFixed(0)}';
    }
    return '₹${product.sellingPrice.toStringAsFixed(0)}';
  }

  Widget _buildProductImage() {
    if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      final imagePath = 'C:\\motobill\\database\\images\\${product.imagePath}';
      final imageFile = File(imagePath);

      if (imageFile.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          child: Image.file(
            imageFile,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          ),
        );
      }
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(AppSizes.radiusM),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: AppSizes.iconXL,
        color: AppColors.textTertiary,
      ),
    );
  }
}
