import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Referensi ke Firebase Realtime Database (node: laporan_harian)
  final DatabaseReference _database = FirebaseDatabase.instance.ref("laporan_harian");

  // Menyimpan data penjualan dari Firebase
  Map<String, dynamic> salesData = {};

  // Filter yang dipilih untuk chart (omset, modal, laba)
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
    _fetchSalesData();
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
  /// (bukan hanya hari ini).
  /// Menghitung total omset, laba, jumlah item terjual,
  /// serta produk terlaris (berdasarkan `laku` terbesar).
  Map<String, dynamic> _getAllSummary() {
    double totalOmset = 0;
    double totalLaba = 0;
    int totalLaku = 0;

    String topProductId = '';
    int topProductLaku = 0;

    // Iterasi setiap tanggal di salesData
    for (String dateStr in salesData.keys) {
      final dayData = salesData[dateStr];
      if (dayData is Map) {
        // Iterasi setiap produk di hari tersebut
        dayData.forEach((key, value) {
          if (value is Map) {
            double omset = (value['omset'] as num?)?.toDouble() ?? 0;
            double laba = (value['laba'] as num?)?.toDouble() ?? 0;
            int laku = (value['laku'] as num?)?.toInt() ?? 0;

            totalOmset += omset;
            totalLaba += laba;
            totalLaku += laku;

            // Cek produk terlaris (yang paling banyak laku)
            if (laku > topProductLaku) {
              topProductLaku = laku;
              topProductId = key; // contoh: p001, p002
            }
          }
        });
      }
    }

    return {
      'omset': totalOmset,
      'laba': totalLaba,
      'laku': totalLaku,
      'topProductId': topProductId,
    };
  }

  List<FlSpot> _getWeeklySpots() {
    List<FlSpot> spots = [];
    if (salesData.isEmpty) return spots;

    List<String> dateKeys = salesData.keys.toList();
    dateKeys.sort();

    List<DateTime> validDates = [];

    // Gunakan 7 hari terakhir: mulai dari 6 hari yang lalu hingga hari ini
    DateTime today = DateTime.now();
    DateTime startOfPeriod = today.subtract(const Duration(days: 6));

    for (String dateStr in dateKeys) {
      DateTime parsedDate;
      try {
        parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
      } catch (_) {
        continue;
      }

      // Hanya ambil tanggal dalam rentang periode (startOfPeriod s.d. today)
      if (parsedDate.isBefore(startOfPeriod) || parsedDate.isAfter(today)) {
        continue;
      }

      double dailyTotal = 0;
      final dayData = salesData[dateStr];
      if (dayData is Map) {
        dayData.forEach((key, value) {
          if (value is Map && value[selectedFilter] != null) {
            dailyTotal += (value[selectedFilter] as num).toDouble();
          }
        });
      }

      validDates.add(parsedDate);
      // Gunakan dailyTotal langsung, tanpa menambahkan nilai hari sebelumnya
      spots.add(FlSpot((validDates.length - 1).toDouble(), dailyTotal));
    }
    return spots;
  }

  List<DateTime> _getWeeklyDates() {
    List<DateTime> result = [];
    if (salesData.isEmpty) return result;

    // Gunakan 7 hari terakhir: mulai dari 6 hari yang lalu hingga hari ini
    DateTime today = DateTime.now();
    DateTime startOfPeriod = today.subtract(const Duration(days: 6));

    List<String> dateKeys = salesData.keys.toList();
    dateKeys.sort();

    for (String dateStr in dateKeys) {
      try {
        DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        if (!parsedDate.isBefore(startOfPeriod) && !parsedDate.isAfter(today)) {
          result.add(parsedDate);
        }
      } catch (_) {}
    }
    result.sort();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final allSummary = _getAllSummary(); // ringkasan semua data
    final weeklySpots = _getWeeklySpots();
    final weeklyDates = _getWeeklyDates();

    // Format data ringkasan untuk ditampilkan di card
    final String omsetStr = _currencyFormat.format(allSummary['omset'] ?? 0);
    final String labaStr = _currencyFormat.format(allSummary['laba'] ?? 0);
    final int lakuInt = (allSummary['laku'] ?? 0) as int;
    final String topProduct = allSummary['topProductId'] ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Penjualan Mingguan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // CARD: Ringkasan Penjualan Total (semua data)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                // Gunakan Column agar bisa menempatkan 2 Row
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Laporan Penjualan",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        // Ikon share atau print misalnya
                        IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () {
                            // Aksi, misal share
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Row pertama: Omset & Laba
                    Row(
                      children: [
                        // Total Omset
                        Expanded(
                          child: Column(
                            children: [
                              const Icon(Icons.attach_money, color: Colors.blue),
                              const SizedBox(height: 4),
                              const Text("Total Omset",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  )),
                              Text(
                                omsetStr,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Total Laba
                        Expanded(
                          child: Column(
                            children: [
                              const Icon(Icons.trending_up, color: Colors.green),
                              const SizedBox(height: 4),
                              const Text("Total Laba",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  )),
                              Text(
                                labaStr,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Row kedua: Penjualan & Produk Terlaris
                    Row(
                      children: [
                        // Total Penjualan
                        Expanded(
                          child: Column(
                            children: [
                              const Icon(Icons.shopping_cart, color: Colors.orange),
                              const SizedBox(height: 4),
                              const Text("Total Penjualan",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  )),
                              Text(
                                "$lakuInt Items",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Produk Terlaris
                        Expanded(
                          child: Column(
                            children: [
                              const Icon(Icons.star, color: Colors.purple),
                              const SizedBox(height: 4),
                              const Text("Produk Terlaris",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  )),
                              Text(
                                topProduct,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
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

            // Dropdown Filter (omset, modal, laba)
            DropdownButton<String>(
              value: selectedFilter,
              items: ["omset", "modal", "laba"].map((filter) {
                return DropdownMenuItem<String>(
                  value: filter,
                  child: Text(filter.toUpperCase()),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedFilter = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // CARD: Chart (dengan tinggi lebih kecil agar label rapi)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  height: 300, // Batas tinggi chart agar label tidak rusak
                  child: LineChart(
                    LineChartData(
                      // Grid
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 20000,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey.shade300,
                          strokeWidth: 1,
                        ),
                        getDrawingVerticalLine: (value) => FlLine(
                          color: Colors.grey.shade200,
                          strokeWidth: 1,
                        ),
                      ),
                      // Border
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      // Titles (label sumbu)
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            getTitlesWidget: (value, meta) {
                              // Tampilkan label K (contoh: 180K)
                              if (value < 0) return const SizedBox.shrink();
                              final val = value.toInt();
                              if (val >= 1000) {
                                final inK = val ~/ 1000;
                                return Text('${inK}K');
                              }
                              return Text(val.toString());
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              int idx = value.toInt();
                              if (idx < 0 || idx >= weeklyDates.length) {
                                return const SizedBox.shrink();
                              }
                              // Tampilkan format MM/dd
                              final date = weeklyDates[idx];
                              final label = DateFormat('MM/dd').format(date);
                              return SideTitleWidget(
                                meta: meta, // WAJIB untuk fl_chart ^0.70.2
                                child: Transform.rotate(
                                  angle: -45 * pi / 180,
                                  child: Text(
                                    label,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      // Data garis
                      lineBarsData: [
                        LineChartBarData(
                          spots: weeklySpots,
                          isCurved: true,
                          color: Colors.yellow,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                Colors.yellow.withOpacity(0.2),
                                Colors.yellow.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
