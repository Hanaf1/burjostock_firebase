import 'package:burjo_stock/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'home_screen.dart';
import 'stock_input_screen.dart';
import 'report_screen.dart';
import 'product_screen.dart';
import 'login_screen.dart';
import 'package:flutter/services.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String _userRole = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
        return;
      }

      // Debug: Print user ID
      print('Loading role for user ID: ${user.uid}');

      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users/${user.uid}')
          .get();

      if (snapshot.exists) {
        Map<String, dynamic> userData =
        Map<String, dynamic>.from(snapshot.value as Map);

        // Debug: Print raw user data and role
        print('Raw user data: $userData');
        if (userData.containsKey('role')) {
          print('Role found: "${userData['role']}"');
        } else {
          print('Role not found in user data');
        }

        if (mounted) {
          setState(() {
            // Explicitly clean the role string to avoid whitespace issues
            String roleValue = (userData['role'] ?? "KARYAWAN").toString().trim();
            // Remove any quotes from the role value
            roleValue = roleValue.replaceAll('"', '');
            _userRole = roleValue;
            _isLoading = false;
          });
        }

        // Debug: Print cleaned role value
        print('Role set to: "$_userRole"');
      } else {
        print('User data not found in database');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _userRole = "KARYAWAN";
          });
        }
      }
    } catch (e) {
      print('Error loading user role: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _userRole = "KARYAWAN";
        });
      }
    }
  }


  bool _isPemilik() {
    // Normalize and compare role to avoid issues with whitespace or case
    String normalizedRole = _userRole.trim().toUpperCase();
    // Remove any quotes that might be in the string
    normalizedRole = normalizedRole.replaceAll('"', '');

    bool isPemilik = normalizedRole == "PEMILIK";

    // Debug: Print comparison details
    print('Normalized role: "$normalizedRole"');
    print('Is Pemilik check result: $isPemilik');

    return isPemilik;
  }

  int _convertIndexForKaryawan(int index) {
    // For KARYAWAN: if index >= 3, add 1 to skip the Report screen (index 3)
    return index >= 3 ? index + 1 : index;
  }

  // Custom widget for icon with pill-shaped background like in the image
  Widget _buildIconWithBackground(IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF63B4FF).withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: isSelected ? const Color(0xFFB58484) : Colors.grey,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Debug info
    print('Building UI with role: "$_userRole"');
    print('isPemilik() returns: ${_isPemilik()}');

    // Daftar screen (semua screen untuk semua role)
    final List<Widget> allScreens = [
      const HomeScreen(),
      const ProductScreen(),
      const StockInputScreen(),
      const ReportScreen(),
      const SettingsScreen(),
    ];

    // Daftar item navigasi berdasarkan role
    final bool isPemilik = _isPemilik();

    // Navigation items for PEMILIK (all items)
    final List<BottomNavigationBarItem> pemilikNavItems = [
      BottomNavigationBarItem(
        icon: _buildIconWithBackground(Icons.home, _selectedIndex == 0),
        activeIcon: _buildIconWithBackground(Icons.home, true),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: _buildIconWithBackground(Icons.store, _selectedIndex == 1),
        activeIcon: _buildIconWithBackground(Icons.store, true),
        label: 'Store',
      ),
      BottomNavigationBarItem(
        icon: _buildIconWithBackground(Icons.book, _selectedIndex == 2),
        activeIcon: _buildIconWithBackground(Icons.book, true),
        label: 'Book',
      ),
      BottomNavigationBarItem(
        icon: _buildIconWithBackground(Icons.attach_money, _selectedIndex == 3),
        activeIcon: _buildIconWithBackground(Icons.attach_money, true),
        label: 'Money',
      ),
      BottomNavigationBarItem(
        icon: _buildIconWithBackground(Icons.person, _selectedIndex == 4),
        activeIcon: _buildIconWithBackground(Icons.person, true),
        label: 'Person',
      ),
    ];

    // Navigation items for KARYAWAN (without Money icon)
    final List<BottomNavigationBarItem> karyawanNavItems = [
      BottomNavigationBarItem(
        icon: _buildIconWithBackground(Icons.home, _selectedIndex == 0),
        activeIcon: _buildIconWithBackground(Icons.home, true),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: _buildIconWithBackground(Icons.store, _selectedIndex == 1),
        activeIcon: _buildIconWithBackground(Icons.store, true),
        label: 'Store',
      ),
      BottomNavigationBarItem(
        icon: _buildIconWithBackground(Icons.book, _selectedIndex == 2),
        activeIcon: _buildIconWithBackground(Icons.book, true),
        label: 'Book',
      ),
      BottomNavigationBarItem(
        icon: _buildIconWithBackground(Icons.person, _selectedIndex == 3),
        activeIcon: _buildIconWithBackground(Icons.person, true),
        label: 'Person',
      ),
    ];

    // Get actual screen index based on role and selected index
    int actualScreenIndex = _selectedIndex;
    if (!isPemilik && _selectedIndex >= 3) {
      actualScreenIndex = _selectedIndex == 3 ? 4 : _selectedIndex;
    }

    return Scaffold(
      body: isPemilik || actualScreenIndex != 3
          ? allScreens[actualScreenIndex]
          : const Center(
        child: Text(
          'Fitur ini hanya tersedia untuk Pemilik',
          style: TextStyle(fontSize: 18),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            // Only handle tap if access is allowed
            setState(() {
              _selectedIndex = index;
            });
          },
          elevation: 0, // Remove default shadow
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          items: isPemilik ? pemilikNavItems : karyawanNavItems,
        ),
      ),
    );
  }
}