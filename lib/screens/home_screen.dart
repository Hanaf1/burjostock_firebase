import 'package:burjo_stock/screens/day_detail_screen.dart';
import 'package:burjo_stock/screens/lowstock_screen.dart';
import 'package:burjo_stock/screens/notification_screen.dart';
import 'package:burjo_stock/screens/product_screen.dart';
import 'package:burjo_stock/screens/report_screen.dart';
import 'package:burjo_stock/screens/stock_input_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_fonts/google_fonts.dart';

// Pindahkan CustomPainter di luar kelas utama
class DiagonalStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (double i = -2 * size.width; i < 2 * size.width; i += 10) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();

}

class _HomeScreenState extends State<HomeScreen> {
  String productStatusMessage = "";
  final PageController _pageController = PageController();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  // Data produk
  Map<String, dynamic> _productsData = {};

  String userRole = ""; // misalnya kosong di awal

  final user = FirebaseAuth.instance.currentUser;


  // Status stok harian
  bool isStockInputCompleted = false;
  String stokHarianMessage = "";
  List<Map<String, dynamic>> lowStockProducts = [];

  // Laporan kemarin
  Map<String, dynamic> todayReport = {};

  // Loading indicator
  bool isLoading = true;
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToStockChanges();
    _loadUserRole();
  }

  void _listenToStockChanges() {
    _database.child('stok_harian').onValue.listen((event) {
      if (event.snapshot.value != null) {
        int count = 0;
        final data = event.snapshot.value as Map<dynamic, dynamic>;

        data.forEach((date, products) {
          if (products is Map) {
            products.forEach((productId, productData) {
              if (productData is Map && productData['stok'] is num) {
                int stock = (productData['stok'] as num).toInt();
                if (stock <= 4) {
                  count++;
                }
              }
            });
          }
        });

        if (mounted) {
          setState(() {
            _lowStockCount = count;
          });
        }
      }
    });
  }
  /// Menghasilkan sapaan berdasarkan waktu saat ini
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Selamat Pagi';
    } else if (hour >= 12 && hour < 15) {
      return 'Selamat Siang';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore';
    } else {
      return 'Selamat Malam';
    }
  }


  Future<void> _loadUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Belum login atau user null, atur userRole ke "NONE" atau semacamnya
        setState(() {
          userRole = "NONE";
        });
        return;
      }

      // Ambil role dari path "users/[uid]/role"
      final roleSnap = await _database.child('users/${user.uid}/role').get();

      if (roleSnap.exists && roleSnap.value != null) {
        setState(() {
          userRole = roleSnap.value.toString();
          // misal "KARYAWAN" atau "PEMILIK"
        });
      } else {
        // Jika data tidak ada
        setState(() {
          userRole = "NONE";
        });
      }
    } catch (e) {
      debugPrint("Error loadUserRole: $e");
    }
  }


  Future<void> _loadData() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterday = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(const Duration(days: 1)));

      setState(() {
        isLoading = true;
        stokHarianMessage = "Memuat data...";
        lowStockProducts = [];
        productStatusMessage = "Memuat status produk...";
      });

      // 1. Ambil data products
      final productsSnap = await _database.child('products').get();
      if (productsSnap.exists && productsSnap.value != null) {
        _productsData = Map<String, dynamic>.from(productsSnap.value as Map);
      }

      // 2. Cek progress stok hari ini
      final stockSnap = await _database.child('stok_harian/$today').get();
      if (stockSnap.exists && stockSnap.value != null) {
        final stockData = Map<String, dynamic>.from(stockSnap.value as Map);

        int totalProducts = _productsData.length;
        int filledProducts = stockData.length;
        double progress = totalProducts > 0 ? filledProducts / totalProducts : 0;

        setState(() {
          isStockInputCompleted = progress == 1.0;
          stokHarianMessage = " ${(progress * 100).toStringAsFixed(1)}%";
        });

        // Produk stok menipis
        List<Map<String, dynamic>> tempLowStock = [];
        stockData.forEach((productId, detail) {
          if (detail != null && _productsData.containsKey(productId)) {
            final detailMap = Map<String, dynamic>.from(detail as Map);
            final stok = (detailMap['stok'] as num?)?.toInt() ?? 0;

            if (stok < 5) {
              tempLowStock.add({
                'nama': _productsData[productId]['nama'] ?? 'Produk tidak dikenal',
                'stok': stok,
              });
            }
          }
        });
        setState(() => lowStockProducts = tempLowStock);
      } else {
        setState(() {
          isStockInputCompleted = false;
          stokHarianMessage = "Progress input stok: 0%";
        });
      }

      // Update status produk secara otomatis
      setState(() {
        if (_productsData.isEmpty) {
          productStatusMessage = "Belum ada produk terdaftar.";
        } else {
          productStatusMessage = "Terdapat ${_productsData.length} produk. ";
          if (lowStockProducts.isNotEmpty) {
            productStatusMessage += "Ada ${lowStockProducts.length} produk dengan stok menipis.";
          } else {
            productStatusMessage += "Semua produk dalam kondisi normal.";
          }
        }
      });

      // 3. Laporan kemarin
      final reportSnap = await _database.child('laporan_harian/$yesterday').get();
      if (reportSnap.exists && reportSnap.value != null) {
        final reportData = Map<String, dynamic>.from(reportSnap.value as Map);

        int totalOmset = 0;
        int totalLaba = 0;
        int totalItems = 0;
        String bestProduct = '-';
        int maxSold = 0;

        reportData.forEach((productId, data) {
          if (data != null && _productsData.containsKey(productId)) {
            final detail = Map<String, dynamic>.from(data as Map);
            final omset = (detail['omset'] as num?)?.toInt() ?? 0;
            final laba = (detail['laba'] as num?)?.toInt() ?? 0;
            final sold = (detail['laku'] as num?)?.toInt() ?? 0;

            totalOmset += omset;
            totalLaba += laba;
            totalItems += sold;

            if (sold > maxSold) {
              maxSold = sold;
              bestProduct =
                  _productsData[productId]['nama'] ?? 'Produk tidak dikenal';
            }
          }
        });

        setState(() {
          todayReport = {
            "totalOmset": "Rp ${NumberFormat('#,###').format(totalOmset)}",
            "totalLaba": "Rp ${NumberFormat('#,###').format(totalLaba)}",
            "totalPenjualan": "$totalItems Items",
            "produkTerlaris": bestProduct
          };
        });
      } else {
        setState(() {
          todayReport = {
            "totalOmset": "Rp 0",
            "totalLaba": "Rp 0",
            "totalPenjualan": "0 Items",
            "produkTerlaris": "-"
          };
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Dapatkan tanggal hari ini dalam format yang lebih "user-friendly"
    final todayDate = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // =================================================
              // HEADER (Sapaan + Tanggal + Notifikasi)
              // =================================================
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              todayDate,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Ikon notifikasi (dummy)
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationScreen(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.notifications_none,
                          size: 28,
                        ),
                      ),
                      if (_lowStockCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // =================================================
              // BAGIAN: Kartu "Stock Harian" besar & horizontal
              // =================================================
              SizedBox(
                height: 180, // Tinggi area scroll horizontal
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  controller: _pageController,
                  children: [
                    _buildStockHarianCard(context, stokHarianMessage),
                    _buildProductStatusCard(context, productStatusMessage),
                    if (userRole == "PEMILIK")
                      _buildReportCard(context, "Laba: ${todayReport["totalLaba"] ?? "Rp 0"}"),

                  ],
                ),
              ),
              // Indikator
            Center(
              child: SmoothPageIndicator(
                  controller: _pageController,
                  // Jika role = "KARYAWAN" maka 3 dot, jika "PEMILIK" maka 2 dot
                  count: userRole == "PEMILIK" ? 3 : 2,
                  effect: ExpandingDotsEffect(
                    activeDotColor: Colors.red,
                    dotColor: Colors.grey,
                    dotHeight: 8,
                    dotWidth: 8,
                    spacing: 4,
                  ),
                ),
              ),

        const SizedBox(height: 16),

              // =================================================
              // "View Details" atau Bagian Stok Menipis
              // =================================================
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                // Ganti warna latar kartu dengan merah (atau sesuai desain Anda)
                color: Colors.red[300],
                child: InkWell(
                  onTap: () {
                    // Navigasi ke LowStockScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LowStockScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ikon peringatan di sisi kiri
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red[900],
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Bagian teks di tengah (Expanded)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Stok Menipis",
                                style: TextStyle(
                                  fontFamily:'Poppins' ,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white, // Ubah jadi putih
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Konten stok menipis
                              if (lowStockProducts.isEmpty)
                                Text(
                                  'Semua stok dalam kondisi aman',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70, // Teks abu-abu terang
                                  ),
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ...lowStockProducts.take(2).map((product) {
                                      return Text(
                                        '${product["nama"]}: ${product["stok"]} unit',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                      );
                                    }).toList(),
                                    if (lowStockProducts.length > 2)
                                      Text(
                                        '... dan lainnya',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Panah "chevron" di sisi kanan
                        Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              InkWell(
                onTap: () {
                  final yesterday = DateTime.now().subtract(const Duration(days: 1));
                  final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

                  _database.child('laporan_harian/$yesterdayStr').get().then((snapshot) {
                    if (snapshot.exists && snapshot.value != null) {
                      final data = snapshot.value as Map<Object?, Object?>;
                      final dayData = Map<String, dynamic>.from(
                        data.map((key, value) {
                          if (value is Map) {
                            return MapEntry(
                              key.toString(),
                              Map<String, dynamic>.from(
                                (value as Map<Object?, Object?>).map(
                                      (k, v) => MapEntry(k.toString(), v),
                                ),
                              ),
                            );
                          }
                          return MapEntry(key.toString(), value);
                        }),
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DayDetailScreen(
                            dateStr: yesterdayStr,
                            dayData: dayData,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tidak ada data penjualan untuk kemarin'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }).catchError((error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${error.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                },
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Laporan Penjualan Kemarin",
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[600],
                              size: 24,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.attach_money,
                                iconColor: Colors.blue,
                                title: 'Total Omset',
                                value: todayReport["totalOmset"] ?? 'Rp 0',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.trending_up,
                                iconColor: Colors.green,
                                title: 'Total Laba',
                                value: todayReport["totalLaba"] ?? 'Rp 0',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.shopping_cart,
                                iconColor: Colors.orange,
                                title: 'Total Penjualan',
                                value: todayReport["totalPenjualan"] ?? '0 Items',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.star,
                                iconColor: Colors.purple,
                                title: 'Produk Terlaris',
                                value: todayReport["produkTerlaris"] ?? '-',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )


            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, String reportSummary) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        color: Colors.deepPurple[400],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bagian teks di sisi kiri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Laporan Penjualan",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reportSummary,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.deepPurple[600],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: const Text(
                          "Lihat Detail",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.pie_chart,
                  color: Colors.white,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildStockHarianCard(BuildContext context, String stokHarianMessage) {
    // Ekstrak nilai persentase dari stokHarianMessage
    double progressValue = 0.0;
    try {
      String numericPart = stokHarianMessage.trim().replaceAll("%", "");
      progressValue = double.parse(numericPart) / 100.0;
    } catch (e) {
      progressValue = 0.0;
    }

    // Tentukan pesan status berdasarkan progressValue
    String statusMessage = progressValue >= 1.0
        ? "LOG HARIAN SUDAH TERISI"
        : "LOG BELUM TERISI PENUH";

    // Tentukan warna berdasarkan status
    Color statusColor = progressValue >= 1.0 ? Colors.green : Colors.orange;

    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StockInputScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Judul Card
                Text(
                  "Pantau Stok Harian",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),

                // Informasi stok dengan circular progress
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Circular progress indicator
                    SizedBox(
                      width: 45,
                      height: 45,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              value: progressValue,
                              strokeWidth: 3,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  progressValue >= 1.0 ? Colors.green : Colors.blue
                              ),
                            ),
                          ),
                          Icon(
                            Icons.inventory_2_outlined,
                            color: progressValue >= 1.0 ? Colors.green : Colors.blue,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Progress Input Stok",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stokHarianMessage,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Status message banner
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor,
                      width: 0.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      statusMessage,
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Progress bar
                SizedBox(
                  height: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                          progressValue >= 1.0 ? Colors.green : Colors.blue
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductStatusCard(BuildContext context, String statusMessage) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        // Warna dasar untuk status produk
        color: const Color(0xFF3B82F6), // Contoh: biru cerah
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            // Navigasi ke ProductScreen saat kartu ditekan
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProductScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Bagian teks di sisi kiri
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul
                      Text(
                        "Status Produk",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Menampilkan status produk (misal info stok atau lainnya)
                      Text(
                        statusMessage,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tombol "Lihat Detail"
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB), // Warna tombol yang lebih gelap
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: const Text(
                          "Lihat Detail",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Ikon di sisi kanan (contoh: ikon produk)
                const Icon(
                  Icons.inventory, // Bisa diganti dengan ikon lain yang relevan
                  color: Colors.white,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Card kecil untuk menampilkan info penjualan
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}