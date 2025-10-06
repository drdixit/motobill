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
          Divider(color: AppColors.divider, height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  index: 0,
                  icon: Icons.dashboard,
                  title: 'Desktop',
                ),
                _buildMenuItem(
                  index: 1,
                  icon: Icons.settings,
                  title: 'Masters',
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
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'MotoBill',
            style: TextStyle(
              color: AppColors.sidebarText,
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
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
                color: isSelected ? AppColors.black : AppColors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.sidebarTextSelected
                    : AppColors.sidebarText,
                size: AppSizes.iconM,
              ),
              const SizedBox(width: AppSizes.paddingM),
              Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.sidebarTextSelected
                      : AppColors.sidebarText,
                  fontSize: AppSizes.fontL,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
