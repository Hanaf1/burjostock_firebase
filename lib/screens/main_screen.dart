import 'package:burjo_stock/screens/settings_screen.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'stock_input_screen.dart';
import 'report_screen.dart';
import 'product_screen.dart';
import 'package:flutter/services.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}


class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;



  // Daftar screen yang akan ditampilkan sesuai menu
  static final List<Widget> _screens = <Widget>[
    HomeScreen(),
    ProductScreen(),
    StockInputScreen(),
    ReportScreen(),
    SettingsScreen(),
  ];

  // Ketika item pada BottomNavigationBar ditekan
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildIcon(int index, IconData iconData) {
    bool isSelected = _selectedIndex == index;

    // Jika ini adalah ikon tengah (index 2)
    if (index == 2) {
      return Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFF5252),  // Merah
              Color(0xFFFF9800),  // Oranye
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          iconData,
          color: Colors.white,
          size: 28,
        ),
      );
    }

    // Untuk ikon lainnya
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0x1A63B4FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        iconData,
        color: isSelected ? Colors.brown : Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8, // Menambahkan shadow
        items: [
          BottomNavigationBarItem(
            icon: _buildIcon(0, Icons.home),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(1, Icons.store),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(2, Icons.book),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(3, Icons.attach_money),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: _buildIcon(4, Icons.person),
            label: '',
          ),
        ],
      ),
    );
  }
}