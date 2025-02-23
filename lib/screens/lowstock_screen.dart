import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';


class LowStockScreen extends StatefulWidget {
  const LowStockScreen({Key? key}) : super(key: key);

  @override
  State<LowStockScreen> createState() => _LowStockScreenState();
}

class _LowStockScreenState extends State<LowStockScreen> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> lowStockProducts = [];
  Map<String, dynamic> productDetails = {};
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);
      final productSnapshot = await _database.child('products').get();
      if (productSnapshot.exists) {
        productDetails = Map<String, dynamic>.from(productSnapshot.value as Map);
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final stockSnapshot = await _database.child('stok_harian/$today').get();

      if (stockSnapshot.exists) {
        final stockData = Map<String, dynamic>.from(stockSnapshot.value as Map);
        _processStockData(stockData);
      }

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  void _processStockData(Map<String, dynamic> stockData) {
    List<Map<String, dynamic>> filtered = [];

    stockData.forEach((productId, data) {
      if (productDetails.containsKey(productId)) {
        final stockInfo = Map<String, dynamic>.from(data);
        final productInfo = productDetails[productId];
        final currentStock = stockInfo['stok'] as int;

        if (currentStock <= 5) {
          filtered.add({
            'id': productId,
            'nama': productInfo['nama'],
            'stok': currentStock,
            'hargaBeli': productInfo['hargaBeli'],
            'hargaJual': productInfo['hargaJual'],
          });
        }
      }
    });

    setState(() {
      lowStockProducts = filtered;
    });
  }

  // Menampilkan dialog restock
  Future<void> _showRestockDialog(Map<String, dynamic> product) async {
    final TextEditingController restockController = TextEditingController(text: '1');
    final TextEditingController currentStockController = TextEditingController(text: product['stok'].toString());

    int restockAmount = 1;
    int currentStock = product['stok'];

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Restock ${product['nama']}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Harga Beli: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(product['hargaBeli'])}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    Text(
                      'Harga Jual: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(product['hargaJual'])}',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Form stok saat ini
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextFormField(
                        controller: currentStockController,
                        decoration: InputDecoration(
                          labelText: 'Stok Saat Ini',
                          labelStyle: GoogleFonts.poppins(fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                        ),
                        style: GoogleFonts.poppins(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          setState(() {
                            currentStock = int.tryParse(value) ?? product['stok'];
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Form jumlah restock
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade300, width: 1.5),
                      ),
                      child: TextFormField(
                        controller: restockController,
                        decoration: InputDecoration(
                          labelText: 'Jumlah Restock',
                          labelStyle: GoogleFonts.poppins(fontSize: 14),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                        ),
                        style: GoogleFonts.poppins(),
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          setState(() {
                            restockAmount = int.tryParse(value) ?? 1;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Preview stok setelah restock
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, color: Colors.green.shade700, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Stok Setelah Restock: ${currentStock + restockAmount}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () {
                    _saveRestock(
                      product['id'],
                      currentStock,
                      restockAmount,
                      product['hargaBeli'],
                      product['hargaJual'],
                    ).then((_) {
                      Navigator.of(context).pop();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey[300],
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
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Menyimpan data restock ke Firebase
  Future<void> _saveRestock(String productId, int currentStock, int restockAmount, int hargaBeli, int hargaJual) async {
    setState(() => isSaving = true);

    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Kalkulasi laporan
      final int modal = restockAmount * hargaBeli;
      final int omset = restockAmount * hargaJual;
      final int laba = omset - modal;

      // Update data di Firebase
      final updates = {
        'stok_harian/$today/$productId': {
          'stok': currentStock,
          'beli': restockAmount,
          'timestamp': timestamp
        },
        'laporan_harian/$today/$productId': {
          'laku': restockAmount,
          'modal': modal,
          'omset': omset,
          'laba': laba
        },
      };

      await _database.update(updates);

      // Refresh data setelah update
      _loadData();

      // Tampilkan notifikasi sukses
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restock berhasil disimpan!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error saving restock: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan restock: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Stok Menipis',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : lowStockProducts.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text(
              'Semua stok dalam kondisi aman',
              style: GoogleFonts.poppins(fontSize: 16),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lowStockProducts.length,
        itemBuilder: (context, index) {
          final product = lowStockProducts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${product['stok']}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.red[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['nama'],
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Harga Beli: Rp ${NumberFormat('#,###').format(product['hargaBeli'])}',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        Text(
                          'Harga Jual: Rp ${NumberFormat('#,###').format(product['hargaJual'])}',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showRestockDialog(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add_shopping_cart,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Restock',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}