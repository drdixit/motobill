import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'masters/customers_screen.dart';
import 'masters/vendors_screen.dart';
import 'masters/main_categories_screen.dart';
import 'masters/sub_categories_screen.dart';
import 'masters/products_screen.dart';
import 'masters/hsn_codes_screen.dart';
// import 'masters/gst_rates_screen.dart'; // hidden per request
import 'masters/vehicles_screen.dart';
import 'masters/manufacturers_screen.dart';

class MastersScreen extends StatefulWidget {
  const MastersScreen({super.key});

  @override
  State<MastersScreen> createState() => _MastersScreenState();
}

class _MastersScreenState extends State<MastersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = [
    'Customers',
    'Vendors',
    'Main Categories',
    'Sub Categories',
    'Products',
    'HSN Codes',
    // 'GST', // hidden per request — keep code but don't show the tab
    'Vehicles',
    'Manufacturers',
  ];

  final List<Widget> _tabScreens = [
    const CustomersScreen(),
    const VendorsScreen(),
    const MainCategoriesScreen(),
    const SubCategoriesScreen(),
    const ProductsScreen(),
    const HsnCodesScreen(),
    // const GstRatesScreen(), // hidden per request — keep code but don't show the screen
    const VehiclesScreen(),
    const ManufacturersScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabScreens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: 'Roboto',
          letterSpacing: 0.3,
        ),
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }
}
