import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import 'settings/company_settings_screen.dart';
import 'settings/whatsapp_settings_screen.dart';
import 'settings/printer_settings_screen.dart';
import 'settings/backup_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // Tabs at top
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: AppSizes.fontL,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: AppSizes.fontL,
                  fontWeight: FontWeight.normal,
                  fontFamily: 'Roboto',
                ),
                tabs: const [
                  Tab(text: 'Company'),
                  Tab(text: 'WhatsApp'),
                  Tab(text: 'Printer'),
                  Tab(text: 'Backup'),
                ],
              ),
            ),
            // Tab content
            const Expanded(
              child: TabBarView(
                children: [
                  CompanySettingsScreen(),
                  WhatsappSettingsScreen(),
                  PrinterSettingsScreen(),
                  BackupSettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
