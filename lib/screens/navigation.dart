import 'package:flutter/material.dart';
import 'package:redpdf_tools/screens/home_screen.dart';
import 'package:redpdf_tools/screens/settings_screen.dart';
import 'package:redpdf_tools/screens/tools_screen.dart';
import 'package:redpdf_tools/theme/app_theme.dart';

import 'image_to_pdf_screen.dart';

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  int _selectedIndex = 1;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  static const List<Widget> _pages = [
    HomeScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.appColors;

    return Scaffold(
      backgroundColor: appColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ImageToPdfScreen()),
              ),
              backgroundColor: appColors.primary,
              elevation: 4,
              isExtended: true,
              label: Row(
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 32),
                  Text("IMG to Pdf", style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: appColors.surface,
        elevation: 10,
        selectedItemColor: appColors.primary,
        unselectedItemColor: appColors.subtitle?.withValues(alpha: 0.5),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Files'),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_circle_outlined),
            label: 'Tools',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
