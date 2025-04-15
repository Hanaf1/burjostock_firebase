import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class StockDetailScreen extends StatefulWidget {
  final String date;
  final Map<String, dynamic> productNames;

  const StockDetailScreen({
    Key? key,
    required this.date,
    required this.productNames,
  }) : super(key: key);

  @override
  _StockDetailScreenState createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _stockDetails = [];
  bool _isLoading = true;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Statistik
  int _totalStockCount = 0;
  int _totalPurchaseCount = 0;
  int _lowStockCount = 0;  // Produk dengan stok < 10
  int _totalSoldCount = 0;  // Tambahkan total laku

  @override
  void initState() {
    super.initState();
    _fetchStockDetails();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _fetchStockDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Ambil data stok dari stok_harian
      final stockSnapshot = await _databaseRef.child('stok_harian/${widget.date}').get();

      // Ambil data laporan harian (laku) dari laporan_harian
      final reportSnapshot = await _databaseRef.child('laporan_harian/${widget.date}').get();

      // Inisialisasi data laporan
      Map<String, dynamic> reportData = {};
      if (reportSnapshot.exists && reportSnapshot.value != null) {
        reportData = Map<String, dynamic>.from(reportSnapshot.value as Map);
      }

      // Inisialisasi data stok
      Map<String, dynamic> stockData = {};
      if (stockSnapshot.exists && stockSnapshot.value != null) {
        stockData = Map<String, dynamic>.from(stockSnapshot.value as Map);
      }

      List<Map<String, dynamic>> products = [];
      int totalStock = 0;
      int totalPurchases = 0;
      int lowStockItems = 0;
      int totalSold = 0;

      // Gabungkan semua ID produk dari stok dan laporan
      Set<String> allProductIds = {...stockData.keys};
      reportData.keys.forEach((id) => allProductIds.add(id));

      // Proses setiap produk
      for (String productId in allProductIds) {
        try {
          // Default values
          int stockCount = 0;
          int purchaseCount = 0;
          int soldCount = 0;

          // Ambil data stok jika ada
          if (stockData.containsKey(productId)) {
            var prodStockData = stockData[productId];
            if (prodStockData is Map) {
              // Stok
              if (prodStockData.containsKey('stok')) {
                var stokVal = prodStockData['stok'];
                if (stokVal is int) {
                  stockCount = stokVal;
                } else if (stokVal is String) {
                  stockCount = int.tryParse(stokVal.toString()) ?? 0;
                }
              }

              // Beli
              if (prodStockData.containsKey('beli')) {
                var beliVal = prodStockData['beli'];
                if (beliVal is int) {
                  purchaseCount = beliVal;
                } else if (beliVal is String) {
                  purchaseCount = int.tryParse(beliVal.toString()) ?? 0;
                }
              }
            }
          }

          // Ambil data laku jika ada
          if (reportData.containsKey(productId)) {
            var prodReportData = reportData[productId];
            if (prodReportData is Map) {
              if (prodReportData.containsKey('laku')) {
                var lakuVal = prodReportData['laku'];
                if (lakuVal is int) {
                  soldCount = lakuVal;
                } else if (lakuVal is String) {
                  soldCount = int.tryParse(lakuVal.toString()) ?? 0;
                }
              }
            }
          }

          // Track low stock
          if (stockCount < 10) {
            lowStockItems++;
          }

          // Tambahkan ke total
          totalStock += stockCount;
          totalPurchases += purchaseCount;
          totalSold += soldCount;

          // Tambahkan ke list produk
          products.add({
            'id': productId,
            'name': widget.productNames[productId] ?? 'Produk $productId',
            'stock': stockCount,
            'purchase': purchaseCount,
            'sold': soldCount,
          });
        } catch (e) {
          debugPrint('Error processing product $productId: $e');
        }
      }

      // Sort products by stock (lowest first)
      products.sort((a, b) {
        int stockA = a['stock'] as int;
        int stockB = b['stock'] as int;
        return stockA.compareTo(stockB);
      });

      setState(() {
        _stockDetails = products;
        _totalStockCount = totalStock;
        _totalPurchaseCount = totalPurchases;
        _totalSoldCount = totalSold;
        _lowStockCount = lowStockItems;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching stock details: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredProducts {
    if (_searchQuery.isEmpty) {
      return _stockDetails;
    }

    return _stockDetails.where((product) {
      return product['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(DateTime.parse(widget.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Stok Harian',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.brown,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : Column(
        children: [
          // Header with date
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.brown.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: Colors.brown.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Statistics cards
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard(
                      title: 'Total Stok',
                      value: _totalStockCount,
                      icon: Icons.inventory,
                      color: Colors.blue,
                    ),
                    _buildStatCard(
                      title: 'Total Beli',
                      value: _totalPurchaseCount,
                      icon: Icons.add_shopping_cart,
                      color: Colors.green,
                    ),
                    _buildStatCard(
                      title: 'Total Laku',  // Ganti dari Stok Rendah ke Total Laku
                      value: _totalSoldCount,
                      icon: Icons.shopping_bag,  // Ganti icon
                      color: Colors.purple,  // Ganti warna
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                hintStyle: GoogleFonts.poppins(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Stock legend
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem(color: Colors.red, label: 'Stok Kritis (<5)'),
                _buildLegendItem(color: Colors.orange, label: 'Stok Rendah (<10)'),
                _buildLegendItem(color: Colors.green, label: 'Stok Aman (≥10)'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Product list
          Expanded(
            child: _stockDetails.isEmpty
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
                    'Tidak ada data stok untuk tanggal ini',
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
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                final stockLevel = product['stock'];
                final purchaseCount = product['purchase'];
                final soldCount = product['sold'];

                // Define color based on stock level
                Color stockColor = Colors.green;
                if (stockLevel < 5) {
                  stockColor = Colors.red;
                } else if (stockLevel < 10) {
                  stockColor = Colors.orange;
                }

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: stockColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nama produk
                        Text(
                          product['name'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // Badge row untuk stok, beli, dan laku
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Badge Stok
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: stockColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: stockColor),
                              ),
                              child: Text(
                                'Stok: ${product['stock']}',
                                style: GoogleFonts.poppins(
                                  color: stockColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            ),

                            // Badge Beli
                            if (purchaseCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.green),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add_shopping_cart,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Beli: $purchaseCount',
                                      style: GoogleFonts.poppins(
                                        color: Colors.green,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Badge Laku (baru)
                            if (soldCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.purple),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.shopping_bag,
                                      size: 14,
                                      color: Colors.purple,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Laku: $soldCount',
                                      style: GoogleFonts.poppins(
                                        color: Colors.purple,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.grey[700],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}