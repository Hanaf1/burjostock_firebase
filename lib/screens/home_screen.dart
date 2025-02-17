import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

// Jika Anda punya file lain untuk StockInputScreen / ReportScreen, import di sini
import 'package:burjo_stock/screens/stock_input_screen.dart';
import 'package:burjo_stock/screens/report_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Jadikan productsData milik state
  Map<String, dynamic> _productsData = {};

  // Variabel-variabel lain...
  bool isStockInputCompleted = false;
  String stokHarianMessage = "";
  List<Map<String, dynamic>> lowStockProducts = [];
  Map<String, dynamic> todayReport = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      setState(() {
        isLoading = true;
        stokHarianMessage = "Memuat data...";
        lowStockProducts = [];
      });

      // 1. Ambil data products
      final productsSnap = await _database.child('products').get();
      if (productsSnap.exists && productsSnap.value != null) {
        setState(() {
          // Simpan ke variabel _productsData milik state
          _productsData = Map<String, dynamic>.from(productsSnap.value as Map);
        });
      }

      // 2. Cek stok_harian
      final stokRef = _database.child('stok_harian').child(today);
      final stokSnap = await stokRef.get();
      if (stokSnap.exists && stokSnap.value != null) {
        final stokData = Map<String, dynamic>.from(stokSnap.value as Map);

        // Proses stok untuk stok menipis
        List<Map<String, dynamic>> tempLowStock = [];
        stokData.forEach((productId, detail) {
          if (detail != null) {
            final detailMap = Map<String, dynamic>.from(detail as Map);
            // Pastikan stok bertipe int
            final int stok = (detailMap['stok'] as num?)?.toInt() ?? 0;
            if (stok < 30) {
              // Gunakan _productsData[productId]?['nama'] sebagai nama
              String namaProduk = _productsData[productId]?['nama'] ?? productId;
              tempLowStock.add({
                'name': namaProduk,
                'unit': stok,
              });
            }
          }
        });

        setState(() {
          isStockInputCompleted = true;
          stokHarianMessage = "Anda sudah melakukan input stok hari ini";
          lowStockProducts = tempLowStock;
        });
      } else {
        setState(() {
          isStockInputCompleted = false;
          stokHarianMessage = "Anda belum melakukan input stok hari ini";
          lowStockProducts = [];
        });
      }

      // 3. Ambil data laporan penjualan
      final reportRef = _database.child('laporan_harian').child(today);
      final reportSnap = await reportRef.get();

      if (reportSnap.exists && reportSnap.value != null) {
        final reportData = Map<String, dynamic>.from(reportSnap.value as Map);

        int totalOmset = 0;
        int totalLaba = 0;
        int totalItems = 0;
        String bestProduct = '-';
        int maxSold = 0;

        reportData.forEach((productId, data) {
          if (data != null) {
            final detail = Map<String, dynamic>.from(data as Map);

            // Convert omset, laba, laku ke int
            final int omsetVal = (detail['omset'] as num?)?.toInt() ?? 0;
            final int labaVal  = (detail['laba']  as num?)?.toInt() ?? 0;
            final int soldVal  = (detail['laku']  as num?)?.toInt() ?? 0;

            totalOmset += omsetVal;
            totalLaba  += labaVal;
            totalItems += soldVal;

            // Cek produk terlaris
            if (soldVal > maxSold) {
              maxSold = soldVal;
              // Gunakan _productsData[productId]?['nama'] untuk nama produk
              bestProduct = _productsData[productId]?['nama'] ?? productId;
            }
          }
        });

        setState(() {
          todayReport = {
            "totalOmset": "Rp ${NumberFormat('#,###').format(totalOmset)}",
            "totalLaba":  "Rp ${NumberFormat('#,###').format(totalLaba)}",
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
      setState(() {
        isStockInputCompleted = false;
        stokHarianMessage = "Gagal memuat data stok harian";
        lowStockProducts = [];
        todayReport = {
          "totalOmset": "Rp 0",
          "totalLaba": "Rp 0",
          "totalPenjualan": "0 Items",
          "produkTerlaris": "-"
        };
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
      ),
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // Bagian Atas: Stok Harian dan Stok Menipis
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card Stok Harian
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      // Navigasi ke StockInputScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StockInputScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Baris pertama: ikon, judul, spacer, panah
                          Row(
                            children: [
                              Icon(
                                isStockInputCompleted
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: isStockInputCompleted
                                    ? Colors.green
                                    : Colors.orange,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Stok Harian',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Teks keterangan stok harian
                          Text(
                            stokHarianMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Card Stok Menipis
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      // Navigasi ke ReportScreen (contoh)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>  ReportScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.warning_amber,
                                color: Colors.red,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Stok Menipis',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Spacer(),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (lowStockProducts.isEmpty)
                            Text(
                              'Semua stok dalam kondisi aman',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: lowStockProducts.map((product) {
                                return Text(
                                  '${product["name"]}: ${product["unit"]} unit',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bagian Laporan Penjualan
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header "Laporan Penjualan"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Laporan Penjualan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 2 baris x 2 kolom
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
          ],
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
