import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../report_screen.dart';
import '../stock_daily_screen.dart';

class AnalyticScreen extends StatefulWidget {
  const AnalyticScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticScreen> createState() => _AnalyticScreenState();
}

class _AnalyticScreenState extends State<AnalyticScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  bool isLoading = true;

  // Menyimpan data produk dari "products" (untuk ambil nama, dsb)
  Map<String, dynamic> productsData = {};

  // Menyimpan ringkasan analitik
  Map<String, dynamic> analyticsData = {
    'totalModal': 0,
    'totalRevenue': 0,
    'totalProfit': 0,
    'bestSeller': '-',
    'worstSeller': '-',
    'averagePrice': 0,
  };

  // List untuk menampilkan performance per produk
  List<Map<String, dynamic>> productPerformance = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Memuat data dari Firebase
  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // 1. Load data produk (untuk ambil nama produk, hargaBeli/hargaJual jika diperlukan)
      final productsSnapshot = await _db.child('products').get();
      if (productsSnapshot.exists && productsSnapshot.value != null) {
        productsData = Map<String, dynamic>.from(productsSnapshot.value as Map);
      }

      // 2. Load data laporan_harian untuk bulan ini
      final DateTime now = DateTime.now();
      final DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);
      final List<String> daysInMonth = List.generate(
        now.day,
            (index) {
          final date = firstDayOfMonth.add(Duration(days: index));
          return DateFormat('yyyy-MM-dd').format(date);
        },
      );

      // Kita akan menampung data penjualan per produk (akumulasi per hari)
      final Map<String, int> productLaku = {};
      final Map<String, int> productModal = {};
      final Map<String, int> productOmset = {};
      final Map<String, int> productLaba = {};

      // Akan kita gunakan untuk total
      int totalModal = 0;
      int totalOmset = 0;
      int totalLaba = 0;

      for (String date in daysInMonth) {
        final salesSnapshot = await _db.child('laporan_harian/$date').get();
        if (salesSnapshot.exists && salesSnapshot.value != null) {
          final dayData = Map<String, dynamic>.from(salesSnapshot.value as Map);

          // dayData[productId] => { laku, modal, omset, laba }
          dayData.forEach((productId, data) {
            if (data is Map) {
              final laku = (data['laku'] as num?)?.toInt() ?? 0;
              final modal = (data['modal'] as num?)?.toInt() ?? 0;
              final omset = (data['omset'] as num?)?.toInt() ?? 0;
              final laba = (data['laba'] as num?)?.toInt() ?? 0;

              // Tambahkan ke map akumulasi
              productLaku[productId] = (productLaku[productId] ?? 0) + laku;
              productModal[productId] = (productModal[productId] ?? 0) + modal;
              productOmset[productId] = (productOmset[productId] ?? 0) + omset;
              productLaba[productId] = (productLaba[productId] ?? 0) + laba;

              // Tambahkan ke total bulanan
              totalModal += modal;
              totalOmset += omset;
              totalLaba += laba;
            }
          });
        }
      }

      // 3. Buat list performance per produk
      //    Ambil data 'nama' dari productsData (jika ada)
      productPerformance = productsData.entries.map((entry) {
        final productId = entry.key;
        final productInfo = entry.value;

        final laku = productLaku[productId] ?? 0;
        final modal = productModal[productId] ?? 0;
        final omset = productOmset[productId] ?? 0;
        final laba = productLaba[productId] ?? 0;

        return {
          'id': productId,
          'name': productInfo['nama'] ?? 'Unknown',
          'sales': laku,
          'modal': modal,
          'revenue': omset,
          'profit': laba,
        };
      }).toList();

      // Jika ada produk di 'products' yang sama sekali belum terjual bulan ini,
      // productLaku dsb. akan 0. (Itu normal)

      // 4. Sort productPerformance berdasarkan laku (sales) tertinggi
      productPerformance.sort((a, b) => b['sales'].compareTo(a['sales']));

      // Tentukan bestSeller & worstSeller
      String bestSeller = '-';
      String worstSeller = '-';
      if (productPerformance.isNotEmpty) {
        bestSeller = productPerformance.first['name'];
        worstSeller = productPerformance.last['name'];
      }

      // 5. Hitung averagePrice dari productsData (hargaJual rata-rata)
      int averagePrice = 0;
      if (productsData.isNotEmpty) {
        final hargaList = productsData.values
            .map((p) => (p['hargaJual'] as int?) ?? 0)
            .toList();
        final sumHarga = hargaList.fold(0, (a, b) => a + b);
        averagePrice =
        (hargaList.isEmpty) ? 0 : (sumHarga ~/ hargaList.length);
      }

      // 6. Update analyticsData
      setState(() {
        analyticsData = {
          'totalModal': totalModal,
          'totalRevenue': totalOmset,
          'totalProfit': totalLaba,
          'bestSeller': bestSeller,
          'worstSeller': worstSeller,
          'averagePrice': averagePrice,
        };
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Terjadi kesalahan saat memuat data',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Widget _buildStockReportCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => StockDailyScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Laporan Stok Harian',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.description, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Lihat detail pergerakan stok',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildRevenueReportCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ReportScreen()),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Laporan Pendapatan',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.attach_money, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Lihat rincian pendapatan',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Membangun tampilan kartu metrik (Modal, Omzet, Profit, dsb.)
  Widget _buildMetricCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Membangun tampilan daftar top 5 produk (berdasarkan laku)
  Widget _buildPerformanceList() {
    // Sudah di-sort di _loadData(), tapi kalau mau aman:
    final sortedBySales = [...productPerformance]
      ..sort((a, b) => b['sales'].compareTo(a['sales']));

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Urutan Laku',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...sortedBySales.take(5).map((product) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        product['name'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${product['sales']} pcs',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Pastikan nilai tidak null
    final totalModal = analyticsData['totalModal'] ?? 0;
    final totalRevenue = analyticsData['totalRevenue'] ?? 0;
    final totalProfit = analyticsData['totalProfit'] ?? 0;
    final bestSeller = analyticsData['bestSeller'] ?? '-';
    final worstSeller = analyticsData['worstSeller'] ?? '-';
    final averagePrice = analyticsData['averagePrice'] ?? 0;

    // Hitung profit persentase (hindari bagi 0)
    final profitPercentage =
    (totalRevenue == 0) ? 0.0 : (totalProfit / totalRevenue) * 100;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          'Modal & Profit ${DateFormat('MMM yyyy', 'id').format(DateTime.now())}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.brown,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: _buildStockReportCard()),
              ],
            ),
            const SizedBox(height: 8),
            // Baris kedua
            Row(
              children: [
                Expanded(child: _buildRevenueReportCard()),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Modal',
                    NumberFormat.currency(
                      locale: 'id',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(totalModal),
                    Icons.account_balance_wallet,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Omzet',
                    NumberFormat.currency(
                      locale: 'id',
                      symbol: 'Rp ',
                      decimalDigits: 0,
                    ).format(totalRevenue),
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildMetricCard(
              'Profit',
              NumberFormat.currency(
                locale: 'id',
                symbol: 'Rp ',
                decimalDigits: 0,
              ).format(totalProfit),
              Icons.trending_up,
              Colors.green,
            ),
            const SizedBox(height: 16),

            // Performa Laku
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performa Laku',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Terlaris',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bestSeller,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kurang Laris',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                worstSeller,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Harga Jual Rata-rata',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                NumberFormat.currency(
                                  locale: 'id',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(averagePrice),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Profit Rata-rata',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${profitPercentage.toStringAsFixed(1)}%',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Daftar top 5 produk paling laku
            _buildPerformanceList(),

          ],
        ),
      ),
    );
  }
}
