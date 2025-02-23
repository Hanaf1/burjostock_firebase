
import 'package:burjo_stock/screens/report_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final DatabaseReference _database =
  FirebaseDatabase.instance.ref("laporan_harian");
  bool isLoading = true;

  // Menyimpan data penjualan dari Firebase
  Map<String, dynamic> salesData = {};
  Map<String, String> productNames = {};
  // Filter yang dipilih untuk chart: "laba", "laku", atau "omset"
  String selectedFilter = "omset";

  // Formatter untuk menampilkan angka dalam format Rupiah
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    try {
      await _fetchProductNames();
      _fetchSalesData();
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchProductNames() async {
    try {
      final ref = FirebaseDatabase.instance.ref();
      final snapshot = await ref.child('products').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        productNames = {};
        data.forEach((key, value) {
          productNames[key] = (value as Map)['nama'] ?? 'Produk tidak dikenal';
        });
      }
    } catch (e) {
      print('Error loading product names: $e');
    }
  }
  /// Mendengarkan perubahan data di node "laporan_harian" dan menyimpannya ke salesData
  void _fetchSalesData() {
    _database.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        setState(() {
          salesData = Map<String, dynamic>.from(data);
        });
      }
    });
  }

  /// Mendapatkan ringkasan penjualan untuk semua data di salesData
  Map<String, dynamic> _getAllSummary() {
    double totalOmset = 0;
    double totalLaba = 0;
    double totalModal = 0;
    int totalLaku = 0;


    String topProductId = '';
    String topProductName = '-';
    int topProductLaku = 0;

    // Loop setiap tanggal
    for (String dateStr in salesData.keys) {
      final dayData = salesData[dateStr];
      if (dayData is Map) {
        // Loop setiap produk di tanggal tersebut
        dayData.forEach((key, value) {
          if (value is Map) {
            double omset = (value['omset'] as num?)?.toDouble() ?? 0;
            double laba = (value['laba'] as num?)?.toDouble() ?? 0;
            double modal = (value['modal'] as num?)?.toDouble() ?? 0;
            int laku = (value['laku'] as num?)?.toInt() ?? 0;

            totalOmset += omset;
            totalLaba += laba;
            totalModal += modal;
            totalLaku += laku;

            if (laku > topProductLaku) {
              topProductLaku = laku;
              topProductId = key;
              topProductName = productNames[key] ?? 'Produk tidak dikenal';
            }
          }
        });
      }
    }

    return {
      'omset': totalOmset,
      'laba': totalLaba,
      'modal': totalModal,
      'laku': totalLaku,
      'topProductId': topProductId,
      'topProductName' : topProductName,
    };
  }

  /// Navigasi ke halaman detail laporan penjualan
  void _navigateToSalesDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportDetailsScreen(),
      ),
    );
  }


  /// Mengonversi salesData menjadi list data harian yang sudah diurutkan
  /// dan dibatasi hanya 7 hari terakhir (1 minggu).
  List<Map<String, dynamic>> _getDailyData() {
    List<Map<String, dynamic>> dailyData = [];

    // Ambil kunci tanggal dan urutkan secara kronologis (lama -> baru)
    List<String> dates = salesData.keys.toList();
    dates.sort((a, b) {
      DateTime dateA = DateFormat('yyyy-MM-dd').parse(a);
      DateTime dateB = DateFormat('yyyy-MM-dd').parse(b);
      return dateA.compareTo(dateB);
    });

    // Batasi hanya 7 tanggal terakhir
    if (dates.length > 7) {
      dates = dates.sublist(dates.length - 7);
    }

    // Hitung total omset, laba, dan laku untuk setiap tanggal
    for (String dateStr in dates) {
      final dayData = salesData[dateStr];
      double sumOmset = 0;
      double sumLaba = 0;
      int sumLaku = 0;

      if (dayData is Map) {
        dayData.forEach((key, value) {
          if (value is Map) {
            sumOmset += (value['omset'] as num?)?.toDouble() ?? 0;
            sumLaba += (value['laba'] as num?)?.toDouble() ?? 0;
            sumLaku += (value['laku'] as num?)?.toInt() ?? 0;
          }
        });
      }

      dailyData.add({
        'date': dateStr,
        'omset': sumOmset,
        'laba': sumLaba,
        'laku': sumLaku.toDouble(), // ubah ke double agar konsisten untuk chart
      });
    }

    return dailyData;
  }

  /// Membangun BarChart menggunakan fl_chart
  Widget _buildBarChart() {
    // Ambil data harian (7 hari terakhir)
    List<Map<String, dynamic>> dailyData = _getDailyData();

    // Siapkan BarChartGroupData
    List<BarChartGroupData> barGroups = [];

    // Hitung nilai maksimum (maxY) untuk skala chart
    double maxY = 0;
    for (int i = 0; i < dailyData.length; i++) {
      double value;
      if (selectedFilter == "laba") {
        value = dailyData[i]['laba'];
      } else if (selectedFilter == "laku") {
        value = dailyData[i]['laku'];
      } else {
        // default "omset"
        value = dailyData[i]['omset'];
      }

      if (value > maxY) maxY = value;

      // Buat satu group bar per hari
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              color: Colors.blueAccent,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
    // Tambahkan padding di atas (biar bar tidak nempel)
    maxY = maxY * 1.2;

    // Tentukan interval label sumbu‐Y supaya tidak terlalu rapat
    // misal, bagi 5 segmen. Lalu bulatkan ke atas (ceil).
    double interval = (maxY / 5).ceilToDouble();
    if (interval < 1) interval = 1; // jaga-jaga kalau maxY sangat kecil

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: barGroups,
        // Mengatur judul sumbu (titles)
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              // interval => label hanya muncul di kelipatan ini
              interval: interval,
              // reservedSize => ruang di sisi kiri agar label tidak terpotong
              reservedSize: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
                // value adalah angka di sumbu‐Y
                // Tampilkan sebagai integer
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                int index = value.toInt();
                if (index < 0 || index >= dailyData.length) {
                  return const SizedBox();
                }
                // Format tanggal jadi "dd MMM"
                DateTime dt = DateFormat('yyyy-MM-dd')
                    .parse(dailyData[index]['date']);
                String formatted = DateFormat('dd MMM').format(dt);

                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    formatted,
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        // Mengatur grid
        gridData: FlGridData(
          show: true,
          // Garis horizontal juga mengikuti interval
          horizontalInterval: interval,
        ),
        // Hilangkan border luar chart
        borderData: FlBorderData(show: false),
      ),
    );
  }

  /// Widget untuk tombol filter chart
  Widget _buildChartFilterButton(String label) {
    bool selected = selectedFilter == label.toLowerCase();
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedFilter = label.toLowerCase();
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
    final allSummary = _getAllSummary();

    final String omsetStr = _currencyFormat.format(allSummary['omset'] ?? 0);
    final String labaStr = _currencyFormat.format(allSummary['laba'] ?? 0);
    final int lakuInt = (allSummary['laku'] ?? 0) as int;
    final String topProduct = allSummary['topProductName'] ?? '-';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Laporan Pendapatan',
                style: GoogleFonts.poppins(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Card Laporan Penjualan
            InkWell(
              onTap: _navigateToSalesDetail,
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Laporan Penjualan Semua",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 1.8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildSummaryItem(
                            icon: Icons.attach_money,
                            iconColor: Colors.blue,
                            title: "Total Omset",
                            value: omsetStr,
                          ),
                          _buildSummaryItem(
                            icon: Icons.trending_up,
                            iconColor: Colors.green,
                            title: "Total Laba",
                            value: labaStr,
                          ),
                          _buildSummaryItem(
                            icon: Icons.shopping_cart,
                            iconColor: Colors.orange,
                            title: "Total Penjualan",
                            value: "$lakuInt Items",
                          ),
                          _buildSummaryItem(
                            icon: Icons.star,
                            iconColor: Colors.purple,
                            title: "Produk Terlaris",
                            value: topProduct,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),


            // --- Bar Chart Card ---
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Grafik Harian",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildChartFilterButton("Laba"),
                        _buildChartFilterButton("Laku"),
                        _buildChartFilterButton("Omset"),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      child: _buildBarChart(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Card Statistik Laba
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Statistik Laba",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Keseluruhan",
                            style: GoogleFonts.poppins(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPercentageStat(
                            title: "Dari Modal",
                            value: (allSummary['modal'] > 0)
                                ? (allSummary['laba'] /
                                allSummary['modal'] *
                                100)
                                .toStringAsFixed(1)
                                : "0.0",
                            color: Colors.indigo,
                          ),
                        ),
                        Expanded(
                          child: _buildPercentageStat(
                            title: "Dari Omset",
                            value: (allSummary['omset'] > 0)
                                ? (allSummary['laba'] /
                                allSummary['omset'] *
                                100)
                                .toStringAsFixed(1)
                                : "0.0",
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Laba per Item: "
                          "${allSummary['laku'] > 0 ? _currencyFormat.format(allSummary['laba'] / allSummary['laku']) : 'Rp 0'}",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
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

  // Widget untuk item summary (Laporan Penjualan)
  Widget _buildSummaryItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Widget untuk statistik persentase
  Widget _buildPercentageStat({
    required String title,
    required String value,
    required Color color
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                "$value%",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_upward,
                color: color,
                size: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
