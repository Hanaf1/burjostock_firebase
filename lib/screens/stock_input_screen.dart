import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'stock_daily_screen.dart';

class StockInputScreen extends StatefulWidget {
  final String? initialSelectedProduct;
  const StockInputScreen({Key? key, this.initialSelectedProduct}) : super(key: key);

  @override
  State<StockInputScreen> createState() => _StockInputScreenState();
}

class _StockInputScreenState extends State<StockInputScreen> {
  final todayDate = DateFormat('EEEE, d MMMM').format(DateTime.now());
  Map<String, Map<String, dynamic>> products = {};
  Map<String, Map<String, dynamic>> inputData = {};
  bool isLoading = true;
  bool isSaving = false;

  // ScrollController untuk auto-scroll ke produk yang dipilih
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _initialProductKey = GlobalKey();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Memuat data produk dan stok yang sudah disimpan dari Firebase
  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final productsSnapshot = await _database.child('products').get();
      final stockSnapshot = await _database.child('stok_harian/$today').get();

      if (productsSnapshot.exists) {
        final productsData =
        Map<String, dynamic>.from(productsSnapshot.value as Map);
        final formattedProducts = productsData.map((key, value) =>
            MapEntry(key, Map<String, dynamic>.from(value as Map)));

        Map<String, Map<String, dynamic>> savedStock = {};
        if (stockSnapshot.exists) {
          final stockData =
          Map<String, dynamic>.from(stockSnapshot.value as Map);
          savedStock = stockData.map((key, value) =>
              MapEntry(key, Map<String, dynamic>.from(value as Map)));
        }

        setState(() {
          products = formattedProducts;
          inputData = products.map((key, _) => MapEntry(key, {
            'stok': savedStock[key]?['stok']?.toString() ?? '',
            // Mengambil nilai dari kolom 'beli' untuk restock
            'restock': savedStock[key]?['beli']?.toString() ?? '',
          }));
          isLoading = false;

          // Untuk inisialisasi produk yang dipilih dari layar LowStockScreen
          if (widget.initialSelectedProduct != null &&
              products.containsKey(widget.initialSelectedProduct)) {

            // Set default restock value jika belum ada
            if (inputData[widget.initialSelectedProduct!]?['restock']?.isEmpty ?? true) {
              inputData[widget.initialSelectedProduct!]!['restock'] = '1';
            }

            // Schedule scroll setelah build selesai
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_initialProductKey.currentContext != null) {
                Scrollable.ensureVisible(
                  _initialProductKey.currentContext!,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            });
          }
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  // Menyimpan data stok dan laporan ke Firebase
  Future<void> _saveStockData(String productId) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final stok = int.tryParse(inputData[productId]?['stok'] ?? '0') ?? 0;
    // Ambil nilai dari inputData dengan key 'restock'
    final restock = int.tryParse(inputData[productId]?['restock'] ?? '0') ?? 0;
    final product = products[productId];

    if (product != null) {
      final int hargaBeli = product['hargaBeli'] ?? 0;
      final int hargaJual = product['hargaJual'] ?? 0;
      final int modal = restock * hargaBeli;
      final int omset = restock * hargaJual;
      final int laba = omset - modal;

      // Ubah key dari 'restock' menjadi 'beli' agar sesuai dengan kolom di Firebase
      final updates = {
        'stok_harian/$today/$productId': {
          'stok': stok,
          'beli': restock,
          'timestamp': timestamp
        },
        'laporan_harian/$today/$productId': {
          'laku': restock,
          'modal': modal,
          'omset': omset,
          'laba': laba
        },
      };

      setState(() {
        isSaving = true;
      });
      await _database.update(updates);
      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data stok untuk ${product['nama']} berhasil disimpan!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Menghitung progress input berdasarkan jumlah produk yang sudah diisi stok-nya
  double _calculateProgress() {
    int filled = inputData.values
        .where((data) => data['stok']!.isNotEmpty || data['restock']!.isNotEmpty)
        .length;
    return products.isNotEmpty ? filled / products.length : 0;
  }

  @override
  Widget build(BuildContext context) {
    double progress = _calculateProgress();

    // Filter produk berdasarkan search query (berdasarkan nama produk)
    final filteredProducts = products.entries.where((entry) {
      String productName = entry.value['nama'].toString().toLowerCase();
      return searchQuery.isEmpty || productName.contains(searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Input Stock Harian',
                  style: GoogleFonts.poppins(
                    fontSize: 25,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                    color: Colors.black,
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
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Card untuk mengarahkan ke StockDailyScreen
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StockDailyScreen(),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.brown.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.brown.shade700,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lihat Data Stok Hari Lain',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Pantau stok produk harian Anda',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress Bar dan Indikator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proses Input: ${(progress * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.brown),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 10,
            color: Colors.grey[100],
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari produk...',
                hintStyle: GoogleFonts.poppins(),
                filled: true,
                fillColor: Colors.grey[100],
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      searchQuery = "";
                    });
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),

          // Daftar produk
          Expanded(
            child: isLoading
                ? Center(
              child: CircularProgressIndicator(
                color: Colors.brown,
              ),
            )
                : products.isEmpty
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
                    'Belum ada produk',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
                : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: filteredProducts
                  .map((entry) =>
                  _buildProductInputCard(
                    entry.key,
                    entry.value,
                    entry.key == widget.initialSelectedProduct ? _initialProductKey : null,
                  ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Widget kartu input untuk setiap produk
  Widget _buildProductInputCard(
      String productId, Map<String, dynamic> productData, [Key? cardKey]) {
    bool isFilled = inputData[productId]!['stok']!.isNotEmpty ||
        inputData[productId]!['restock']!.isNotEmpty;

    return Card(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      // Highlight card jika ini adalah produk yang dipilih
      color: productId == widget.initialSelectedProduct ? Colors.blue.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: productId == widget.initialSelectedProduct
            ? BorderSide(color: Colors.blue.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productData['nama'],
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Harga Jual: Rp ${NumberFormat('#,###').format(productData['hargaJual'])}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),

            // Input field untuk Stok
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Stok',
                  labelStyle: GoogleFonts.poppins(fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                ),
                style: GoogleFonts.poppins(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                initialValue: inputData[productId]!['stok'],
                onChanged: (value) =>
                    setState(() => inputData[productId]!['stok'] = value),
              ),
            ),
            const SizedBox(height: 12),

            // Input field untuk Restock
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: productId == widget.initialSelectedProduct
                      ? Colors.blue.shade300
                      : Colors.grey.shade300,
                  width: productId == widget.initialSelectedProduct ? 1.5 : 1,
                ),
              ),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Restock (Opsional)',
                  labelStyle: GoogleFonts.poppins(fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: InputBorder.none,
                ),
                style: GoogleFonts.poppins(),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                initialValue: inputData[productId]!['restock'],
                onChanged: (value) =>
                    setState(() => inputData[productId]!['restock'] = value),
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Simpan
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: isFilled && !isSaving
                    ? () => _saveStockData(productId)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: productId == widget.initialSelectedProduct
                      ? Colors.blue
                      : Colors.brown,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: isFilled && !isSaving ? 2 : 0,
                ),
                child: isSaving
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  'Simpan',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
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
}