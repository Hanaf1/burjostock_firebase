import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> lowStockItems = [];
  bool isLoading = true;
  Map<String, dynamic> _productsData = {};


  @override
  void initState() {
    super.initState();
    initNotifications();
    setupFirebaseMessaging();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Ambil data produk terlebih dahulu
      final productsSnap = await _dbRef.child('products').get();
      if (productsSnap.exists && productsSnap.value != null) {
        setState(() {
          _productsData = Map<String, dynamic>.from(productsSnap.value as Map);
        });
      }

      // Kemudian ambil data stok
      getLowStockItems();
    } catch (e) {
      debugPrint("Error loading products: $e");
    }
  }

  Future<void> initNotifications() async {
    const androidInitialize = AndroidInitializationSettings('app_icon');
    const iosInitialize = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iosInitialize,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  Future<void> setupFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> showNotification(String title, String body) async {
    AndroidNotificationDetails androidDetails = const AndroidNotificationDetails(
      'stock_notification',
      'Stock Alerts',
      channelDescription: 'Notifications for low stock items',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
    );

    DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
    );
  }

  Future<void> getLowStockItems() async {
    setState(() => isLoading = true);

    try {
      // Ambil tanggal hari ini
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final snapshot = await _dbRef.child('stok_harian/$today').get();
      if (snapshot.exists && snapshot.value != null) {
        List<Map<String, dynamic>> items = [];

        Map<dynamic, dynamic> values = snapshot.value as Map;
        values.forEach((productId, productData) {
          if (productData is Map && productData['stok'] is num) {
            int stock = (productData['stok'] as num).toInt();
            if (stock <= 5) {
              // Ambil nama produk dari _productsData
              String productName = _productsData[productId]?['nama'] ?? 'Produk tidak dikenal';

              items.add({
                'id': productId,
                'nama': productName,
                'stok': stock,
              });
            }
          }
        });

        setState(() {
          lowStockItems = items;
          isLoading = false;
        });
      } else {
        setState(() {
          lowStockItems = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Terjadi kesalahan saat mengambil data stok',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifikasi Stok',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.brown,
      ),
      body: RefreshIndicator(
        onRefresh: getLowStockItems,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : lowStockItems.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak ada produk dengan stok menipis',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: lowStockItems.length,
          itemBuilder: (context, index) {
            final item = lowStockItems[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(
                  item['nama'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Stok: ${item['stok']}',
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.warning_rounded,
                      color: Colors.red[700],
                      size: 24,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}