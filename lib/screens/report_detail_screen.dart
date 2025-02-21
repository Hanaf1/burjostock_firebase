import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'day_detail_screen.dart'; // Import screen detail

class ReportDetailsScreen extends StatefulWidget {
  const ReportDetailsScreen({Key? key}) : super(key: key);

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  // Realtime Database reference
  final DatabaseReference _database =
  FirebaseDatabase.instance.ref("laporan_harian");

  // Menyimpan data (sudah dikonversi) dari Firebase
  Map<String, dynamic> _allData = {};

  // Untuk indikator loading
  bool _isLoading = true;

  // State filter
  String _filter = 'Mingguan'; // default: Mingguan
  DateTime? _selectedDate; // dipakai untuk filter "Harian"
  DateTime _startDate =
  DateTime.now().subtract(const Duration(days: 7)); // Mingguan
  DateTime _endDate = DateTime.now();
  int _selectedMonth = DateTime.now().month; // Bulanan
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /// Fungsi REKURSIF untuk mengonversi semua key (di semua level) menjadi string
  Map<String, dynamic> _convertAllKeysToString(
      Map<dynamic, dynamic> source) {
    final Map<String, dynamic> result = {};
    source.forEach((key, value) {
      final newKey = key.toString(); // ubah key jadi string
      if (value is Map) {
        // kalau masih map, rekursif
        result[newKey] = _convertAllKeysToString(value);
      } else {
        // kalau bukan map, langsung assign
        result[newKey] = value;
      }
    });
    return result;
  }

  /// Ambil data dari Firebase, lalu konversi key agar tidak error
  void _fetchData() {
    _database.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        // Konversi semua key (termasuk nested) menjadi string
        final fixedData = _convertAllKeysToString(data);

        setState(() {
          _allData = fixedData;
          _isLoading = false;
        });
      } else {
        // Jika null atau bukan Map
        setState(() {
          _allData = {};
          _isLoading = false;
        });
      }
    });
  }

  /// Filter data sesuai mode (Harian, Mingguan, Bulanan)
  List<Map<String, dynamic>> _getFilteredData() {
    List<Map<String, dynamic>> result = [];

    // Kumpulkan semua tanggal (key) => sort ascending
    List<String> allDates = _allData.keys.toList();
    allDates.sort((a, b) {
      final da = DateFormat('yyyy-MM-dd').parse(a);
      final db = DateFormat('yyyy-MM-dd').parse(b);
      return da.compareTo(db);
    });

    // Loop per tanggal, cek apakah masuk filter
    for (String dateStr in allDates) {
      final dateObj = DateFormat('yyyy-MM-dd').parse(dateStr);
      bool shouldInclude = false;

      switch (_filter) {
        case 'Harian':
          if (_selectedDate != null) {
            shouldInclude = (dateObj.year == _selectedDate!.year) &&
                (dateObj.month == _selectedDate!.month) &&
                (dateObj.day == _selectedDate!.day);
          }
          break;
        case 'Mingguan':
          shouldInclude =
              !dateObj.isBefore(_startDate) && !dateObj.isAfter(_endDate);
          break;
        case 'Bulanan':
          shouldInclude = (dateObj.year == _selectedYear) &&
              (dateObj.month == _selectedMonth);
          break;
      }

      if (shouldInclude) {
        // Hitung ringkasan
        final summary = _calculateDailySummary(dateStr);
        // Simpan data mentah (rawData) kalau butuh di detail
        summary['rawData'] = _allData[dateStr];
        result.add(summary);
      }
    }
    return result;
  }

  /// Hitung ringkasan (modal, laba, omset, laku) untuk satu tanggal
  Map<String, dynamic> _calculateDailySummary(String dateStr) {
    double totalModal = 0;
    double totalLaba = 0;
    double totalOmset = 0;
    int totalLaku = 0;
    int productCount = 0;

    final dayData = _allData[dateStr];
    if (dayData is Map) {
      dayData.forEach((productId, detail) {
        if (detail is Map) {
          totalModal += (detail['modal'] as num?)?.toDouble() ?? 0;
          totalLaba += (detail['laba'] as num?)?.toDouble() ?? 0;
          totalOmset += (detail['omset'] as num?)?.toDouble() ?? 0;
          totalLaku += (detail['laku'] as num?)?.toInt() ?? 0;
          productCount++;
        }
      });
    }

    return {
      "date": dateStr,
      "modal": totalModal,
      "laba": totalLaba,
      "omset": totalOmset,
      "laku": totalLaku,
      "productCount": productCount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Laporan Pendapatan',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.brown,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ------------------------
          // Filter
          // ------------------------
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  'Filter: ',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _filter,
                  isDense: true,
                  underline: Container(
                    height: 1,
                    color: Colors.brown.shade200,
                  ),
                  items: ['Harian', 'Mingguan', 'Bulanan']
                      .map<DropdownMenuItem<String>>(
                        (String value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  )
                      .toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _filter = newValue!;
                    });
                  },
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      // refresh (rebuild) saja
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    'Refresh',
                    style: GoogleFonts.poppins(),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.brown,
                  ),
                ),
              ],
            ),
          ),
          // ------------------------
          // Date selection
          // ------------------------
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                // HARIAN
                if (_filter == 'Harian')
                  InkWell(
                    onTap: () async {
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedDate = pickedDate;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDate != null
                                ? DateFormat('dd MMMM yyyy')
                                .format(_selectedDate!)
                                : 'Pilih Tanggal',
                            style: GoogleFonts.poppins(),
                          ),
                        ],
                      ),
                    ),
                  ),
                // MINGGUAN
                if (_filter == 'Mingguan')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _startDate = pickedDate;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 15),
                              const SizedBox(width: 5),
                              Text(
                                'Mulai: ${DateFormat('dd/MM/yyyy').format(_startDate)}',
                                style: GoogleFonts.poppins(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        'hingga',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            setState(() {
                              _endDate = pickedDate;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 15),
                              const SizedBox(width: 5),
                              Text(
                                'Akhir: ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                                style: GoogleFonts.poppins(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                // BULANAN
                if (_filter == 'Bulanan')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<int>(
                          value: _selectedMonth,
                          isDense: true,
                          underline: Container(height: 0),
                          items: List.generate(12, (index) => index + 1)
                              .map((month) => DropdownMenuItem<int>(
                            value: month,
                            child: Text(
                              DateFormat('MMMM')
                                  .format(DateTime(0, month)),
                              style: GoogleFonts.poppins(),
                            ),
                          ))
                              .toList(),
                          onChanged: (int? newValue) {
                            setState(() {
                              _selectedMonth = newValue!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<int>(
                          value: _selectedYear,
                          isDense: true,
                          underline: Container(height: 0),
                          items: List.generate(
                            10,
                                (index) => DateTime.now().year - index,
                          )
                              .map((year) => DropdownMenuItem<int>(
                            value: year,
                            child: Text(
                              year.toString(),
                              style: GoogleFonts.poppins(),
                            ),
                          ))
                              .toList(),
                          onChanged: (int? newValue) {
                            setState(() {
                              _selectedYear = newValue!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // ------------------------
          // LIST DATA
          // ------------------------
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Builder(
              builder: (context) {
                final filteredData = _getFilteredData();

                if (filteredData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada data untuk periode ini',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredData.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final data = filteredData[index];
                    final dateStr = data['date'] as String;
                    final rawData =
                    data['rawData'] as Map<String, dynamic>;
                    final DateTime dt = DateTime.parse(dateStr);

                    final double modal = data['modal'];
                    final double laba = data['laba'];
                    final double omset = data['omset'];
                    final int laku = data['laku'];
                    final int productCount = data['productCount'];

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          // Navigasi ke DayDetailScreen ketika card di tap
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DayDetailScreen(
                                dateStr: dateStr,
                                dayData: rawData,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Baris tanggal dengan ikon di kanan
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('EEEE, dd MMMM yyyy')
                                        .format(dt),
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildSummaryBox(
                                    label: "Modal",
                                    value: modal.toInt().toString(),
                                    color: Colors.blue,
                                  ),
                                  _buildSummaryBox(
                                    label: "Laku",
                                    value: laku.toString(),
                                    color: Colors.orange,
                                  ),
                                  _buildSummaryBox(
                                    label: "Produk",
                                    value: productCount.toString(),
                                    color: Colors.teal,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Laba: Rp ${laba.toInt()}",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.brown,
                                ),
                              ),
                              Text(
                                "Omset: Rp ${omset.toInt()}",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
