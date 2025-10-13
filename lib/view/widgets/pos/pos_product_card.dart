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

                          // Price
                          Text(
                            '₹${product.sellingPrice.toStringAsFixed(0)}',
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
