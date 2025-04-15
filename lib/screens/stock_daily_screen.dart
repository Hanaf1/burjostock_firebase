import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'stock_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class StockDailyScreen extends StatefulWidget {
  const StockDailyScreen({Key? key}) : super(key: key);

  @override
  _StockDailyScreenState createState() => _StockDailyScreenState();
}

class _StockDailyScreenState extends State<StockDailyScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref().child('stok_harian');
  final DatabaseReference _productsRef = FirebaseDatabase.instance.ref().child('products');
  final DatabaseReference _reportRef = FirebaseDatabase.instance.ref().child('laporan_harian');

  List<Map<String, dynamic>> _filteredStock = [];
  String _filter = 'Mingguan'; // Default filter ke Mingguan
  DateTime? _selectedDate;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  Map<String, dynamic> _productNames = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProductNames();
  }

  // Memuat nama produk dari database
  Future<void> _loadProductNames() async {
    try {
      final productsSnapshot = await _productsRef.get();
      if (productsSnapshot.exists) {
        Map<String, dynamic> productData = Map<String, dynamic>.from(productsSnapshot.value as Map);
        Map<String, dynamic> names = {};

        productData.forEach((key, value) {
          Map<String, dynamic> product = Map<String, dynamic>.from(value as Map);
          names[key] = product['nama'] ?? 'Produk $key';
        });

        setState(() {
          _productNames = names;
        });
      }
    } catch (e) {
      debugPrint('Error loading product names: $e');
    }

    _fetchFilteredStock();
  }

  Future<void> _fetchFilteredStock() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stockSnapshot = await _databaseRef.get();
      final reportSnapshot = await _reportRef.get();
      List<Map<String, dynamic>> tempList = [];

      Map<String, dynamic>? allStockData;
      if (stockSnapshot.exists) {
        allStockData = Map<String, dynamic>.from(stockSnapshot.value as Map);
      }

      Map<String, dynamic>? allReportData;
      if (reportSnapshot.exists) {
        allReportData = Map<String, dynamic>.from(reportSnapshot.value as Map);
      }

      if (allStockData != null && allReportData != null) {
        if (_filter == 'Harian' && _selectedDate != null) {
          String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate!);
          await _processDayData(allStockData, allReportData, dateKey, tempList);
        }

        if (_filter == 'Mingguan') {
          DateTime current = _startDate;
          while (current.isBefore(_endDate.add(const Duration(days: 1)))) {
            String dateKey = DateFormat('yyyy-MM-dd').format(current);
            await _processDayData(allStockData, allReportData, dateKey, tempList);
            current = current.add(const Duration(days: 1));
          }
        }

        if (_filter == 'Bulanan') {
          for (int day = 1; day <= 31; day++) {
            DateTime date = DateTime(_selectedYear, _selectedMonth, day);
            if (date.month == _selectedMonth) {
              String dateKey = DateFormat('yyyy-MM-dd').format(date);
              await _processDayData(allStockData, allReportData, dateKey, tempList);
            }
          }
        }
      }

      // Sortir berdasarkan tanggal terbaru di atas
      tempList.sort((a, b) => b['date'].compareTo(a['date']));

      setState(() {
        _filteredStock = tempList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching stock data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _processDayData(
      Map<String, dynamic> allStockData,
      Map<String, dynamic> allReportData,
      String dateKey,
      List<Map<String, dynamic>> tempList) async {
    if (allStockData.containsKey(dateKey)) {
      // Data stok
      Map<String, dynamic> stockData = Map<String, dynamic>.from(allStockData[dateKey] as Map);
      int totalStock = 0;
      int totalBuy = 0;
      int productCount = stockData.length;

      stockData.forEach((prodId, prodData) {
        Map<String, dynamic> productStockData = Map<String, dynamic>.from(prodData as Map);
        totalStock += int.tryParse(productStockData['stok']?.toString() ?? '0') ?? 0;
        totalBuy += int.tryParse(productStockData['beli']?.toString() ?? '0') ?? 0;
      });

      // Data laporan (laba & laku)
      int totalProfit = 0;
      int totalSold = 0;

      if (allReportData.containsKey(dateKey)) {
        Map<String, dynamic> reportData = Map<String, dynamic>.from(allReportData[dateKey] as Map);

        reportData.forEach((prodId, prodData) {
          Map<String, dynamic> productReportData = Map<String, dynamic>.from(prodData as Map);
          totalProfit += int.tryParse(productReportData['laba']?.toString() ?? '0') ?? 0;
          totalSold += int.tryParse(productReportData['laku']?.toString() ?? '0') ?? 0;
        });
      }

      tempList.add({
        'date': dateKey,
        'totalStock': totalStock,
        'totalBuy': totalBuy,
        'totalSold': totalSold,
        'totalProfit': totalProfit,
        'productCount': productCount
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Laporan Stok Harian',
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
          // Filter options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                    _fetchFilteredStock();
                  },
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _fetchFilteredStock();
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

          // Date selection based on filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
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
                        _fetchFilteredStock();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                ? DateFormat('dd MMMM yyyy').format(_selectedDate!)
                                : 'Pilih Tanggal',
                            style: GoogleFonts.poppins(),
                          ),
                        ],
                      ),
                    ),
                  ),

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
                            _fetchFilteredStock();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            _fetchFilteredStock();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

                if (_filter == 'Bulanan')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              DateFormat('MMMM').format(DateTime(0, month)),
                              style: GoogleFonts.poppins(),
                            ),
                          ))
                              .toList(),
                          onChanged: (int? newValue) {
                            setState(() {
                              _selectedMonth = newValue!;
                            });
                            _fetchFilteredStock();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<int>(
                          value: _selectedYear,
                          isDense: true,
                          underline: Container(height: 0),
                          items: List.generate(10, (index) => DateTime.now().year - index)
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
                            _fetchFilteredStock();
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // List of stock by date
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.brown))
                : _filteredStock.isEmpty
                ? Center(
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
                    'Tidak ada data stok untuk periode ini',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredStock.length,
              itemBuilder: (context, index) {
                Map<String, dynamic> stockData = _filteredStock[index];
                String date = stockData['date'];
                int totalStock = stockData['totalStock'];
                int totalBuy = stockData['totalBuy'];
                int totalSold = stockData['totalSold'];
                int totalProfit = stockData['totalProfit'];
                int productCount = stockData['productCount'];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StockDetailScreen(
                            date: date,
                            productNames: _productNames,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('EEEE, dd MMMM yyyy').format(DateTime.parse(date)),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem(
                                icon: Icons.inventory,
                                value: totalStock.toString(),
                                label: 'Total Stok',
                                color: Colors.blue,
                              ),
                              _buildStatItem(
                                icon: Icons.add_shopping_cart,
                                value: totalBuy.toString(),
                                label: 'Total Beli',
                                color: Colors.green,
                              ),
                              _buildStatItem(
                                icon: Icons.shopping_cart_checkout,
                                value: totalSold.toString(),
                                label: 'Total Laku',
                                color: Colors.orange,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.trending_up,
                                      color: Colors.purple,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Laba',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        NumberFormat.currency(
                                          locale: 'id',
                                          symbol: 'Rp ',
                                          decimalDigits: 0,
                                        ).format(totalProfit),
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.category_outlined, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$productCount Produk',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[700],
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}