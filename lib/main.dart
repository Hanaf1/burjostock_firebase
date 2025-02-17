import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_screen.dart';
import 'screens/stock_input_screen.dart';
import 'screens/report_screen.dart';
import 'screens/product_screen.dart';

void main() async {
  // Simpan hasil ensureInitialized ke variabel
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Pertahankan splash sebelum inisialisasi
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Inisialisasi Firebase dengan konfigurasi
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyD9hzjuW51yF2ZhdCL_PJhGB0utKfwp4ls',
      authDomain: 'burjonet-zeroes.firebaseapp.com',
      databaseURL: 'https://burjonet-zeroes-default-rtdb.asia-southeast1.firebasedatabase.app',
      projectId: 'burjonet-zeroes',
      storageBucket: 'burjonet-zeroes.firebasestorage.app',
      messagingSenderId: '341450839119',
      appId: '1:341450839119:web:685a6336d14e784089c63a',
    ),
  );

  // Setelah semua siap, jalankan aplikasi
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Hapus splash di frame pertama build
    FlutterNativeSplash.remove();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Burjo Stock',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF8D7B68),
          secondary: Color(0xFFFF4444),
          surface: Colors.white,
          error: Color(0xFFFF4444),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.brown,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = <Widget>[
    HomeScreen(),
    StockInputScreen(),
    ReportScreen(),
    const ProductScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF8D7B68),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: '',
          ),
        ],
      ),
    );
  }
}