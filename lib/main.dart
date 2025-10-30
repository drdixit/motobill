import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/constants/app_colors.dart';
import 'view/widgets/app_sidebar.dart';
import 'view/widgets/date_picker_dialog.dart';
import 'view/screens/dashboard_screen.dart';
import 'view/screens/pos_screen.dart';
import 'view/screens/transactions_screen.dart';
import 'view/screens/masters_screen.dart';
import 'view/screens/settings_screen.dart';
import 'view/screens/testing_screen.dart';
import 'view/screens/product_upload_screen.dart';

void main() {
  // Initialize sqflite for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MotoBill',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.appBarBackground,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSidebarOpen = false;
  int _selectedIndex = 0;

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  void _onMenuItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
      _isSidebarOpen = false; // Close sidebar after selection
    });

    // Refresh dashboard data when navigating to Dashboard screen
    if (index == 0) {
      ref.invalidate(salesStatsProvider);
      ref.invalidate(purchaseStatsProvider);
    }
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const PosScreen();
      case 2:
        return const TransactionsScreen();
      case 3:
        return const MastersScreen();
      case 4:
        return const SettingsScreen();
      case 5:
        return const TestingScreen();
      case 6:
        return const ProductUploadScreen();
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              _buildAppBar(),
              Expanded(child: _getSelectedScreen()),
            ],
          ),
          // Sidebar overlay
          if (_isSidebarOpen)
            GestureDetector(
              onTap: _toggleSidebar,
              child: Container(color: AppColors.overlay),
            ),
          // Sidebar
          if (_isSidebarOpen)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AppSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onMenuItemSelected,
                onClose: _toggleSidebar,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    final isTransactionsScreen = _selectedIndex == 2;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.appBarBackground,
        border: Border(
          bottom: BorderSide(color: AppColors.appBarBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.menu, color: AppColors.appBarIcon),
            onPressed: _toggleSidebar,
          ),
          Text(
            'MotoBill',
            style: TextStyle(
              color: AppColors.appBarText,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
            ),
          ),
          if (isTransactionsScreen) ...[
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Consumer(
                builder: (context, ref, child) {
                  final dateRange = ref.watch(transactionDateRangeProvider);
                  return InkWell(
                    onTap: () async {
                      final picked = await showTransactionDateRangePicker(
                        context,
                        dateRange,
                      );
                      if (picked != null) {
                        ref.read(transactionDateRangeProvider.notifier).state =
                            picked;
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.primary.withOpacity(0.05),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${formatDate(dateRange.start)} - ${formatDate(dateRange.end)}',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
