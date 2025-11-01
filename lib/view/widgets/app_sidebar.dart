import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final VoidCallback onClose;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.sidebarWidth,
      decoration: BoxDecoration(
        color: AppColors.sidebarBackground,
        border: Border(
          right: BorderSide(color: AppColors.sidebarBorder, width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Divider(color: AppColors.sidebarBorder, height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  index: 0,
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                ),
                _buildMenuItem(
                  index: 1,
                  icon: Icons.point_of_sale,
                  title: 'POS',
                ),
                _buildMenuItem(
                  index: 2,
                  icon: Icons.receipt_long,
                  title: 'Transactions',
                ),
                _buildMenuItem(
                  index: 3,
                  icon: Icons.category,
                  title: 'Masters',
                ),
                _buildMenuItem(
                  index: 4,
                  icon: Icons.settings,
                  title: 'Settings',
                ),
                _buildMenuItem(index: 5, icon: Icons.science, title: 'Testing'),
                _buildMenuItem(
                  index: 6,
                  icon: Icons.cloud_upload,
                  title: 'Product Upload',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: AppSizes.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.sidebarBorder, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Motobill',
            style: TextStyle(
              color: AppColors.sidebarText,
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.sidebarText),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final isSelected = selectedIndex == index;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () => onItemSelected(index),
        hoverColor: AppColors.sidebarHover,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingM,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.sidebarSelected
                : AppColors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.sidebarText,
                size: AppSizes.iconM,
              ),
              const SizedBox(width: AppSizes.paddingM),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.sidebarText,
                  fontSize: AppSizes.fontL,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontFamily: 'Roboto',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
