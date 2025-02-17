import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StockInputScreen extends StatefulWidget {
  const StockInputScreen({Key? key}) : super(key: key);

  @override
  State<StockInputScreen> createState() => _StockInputScreenState();
}

class _StockInputScreenState extends State<StockInputScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isCompleted = false;
  final String _completedKey = 'is_stock_completed';

  Map<String, Map<String, dynamic>> products = {};
  Map<String, Map<String, dynamic>> inputData = {};
  bool isLoading = true;

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
        inputData = {};
        products = {};
      });

      // Load completed status
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_completedKey) ?? false;

      // Load products data
      final productsSnapshot = await _database.child('products').get();
      if (productsSnapshot.exists) {
        final productsData = Map<String, dynamic>.from(productsSnapshot.value as Map);

        // Format products data dengan harga
        final formattedProducts = productsData.map((key, value) {
          return MapEntry(key, Map<String, dynamic>.from(value as Map));
        });

        // Siapkan input data kosong untuk setiap produk
        final newInputData = productsData.map((key, value) {
          return MapEntry(key, {
            'stok': '',
            'restock': '',
            'timestamp': 0,
          });
        });

        // Cek data stok hari ini
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todaySnapshot = await _database.child('stok_harian/$today').get();

        if (todaySnapshot.exists) {
          // Jika sudah ada data hari ini, load data tersebut
          final todayData = Map<String, dynamic>.from(todaySnapshot.value as Map);
          setState(() {
            isCompleted = true;
            inputData = todayData.map((key, value) {
              final data = Map<String, dynamic>.from(value as Map);
              return MapEntry(key, {
                'stok': data['stok'].toString(),
                'restock': data['restock']?.toString() ?? '',
                'timestamp': data['timestamp'],
              });
            });
          });
        } else {
          // Jika belum ada data, gunakan input kosong
          setState(() {
            inputData = newInputData;
            isCompleted = completed;
          });
        }

        setState(() {
          products = formattedProducts;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _saveStockData() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 1. Prepare data stok dan laporan
      final Map<String, Map<String, dynamic>> stockData = {};
      final Map<String, Map<String, dynamic>> reportData = {};

      inputData.forEach((productId, value) {
        final int stok = int.tryParse(value['stok'] ?? '0') ?? 0;
        final int restock = int.tryParse(value['restock'] ?? '0') ?? 0;

        // Simpan data stok
        stockData[productId] = {
          'stok': stok,
          'restock': restock,
          'timestamp': timestamp,
        };

        // Hitung data laporan
        final product = products[productId];
        if (product != null) {
          final int hargaBeli = product['hargaBeli'] ?? 0;
          final int hargaJual = product['hargaJual'] ?? 0;

          final int modal = restock * hargaBeli;  // Modal = restock × harga beli
          final int omset = restock * hargaJual;  // Omset = restock × harga jual
          final int laba = omset - modal;         // Laba = omset - modal

          reportData[productId] = {
            'laku': restock, // Jumlah terjual
            'modal': modal,
            'omset': omset,
            'laba': laba,
          };
        }
      });

      // 2. Update ke database
      final Map<String, dynamic> updates = {
        'stok_harian/$today': stockData,
        'laporan_harian/$today': reportData,
      };

      await _database.update(updates);
      await _saveCompletedStatus(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error saving data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveCompletedStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, status);
    setState(() {
      isCompleted = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isCompleted ? 'Status Stok Harian' : 'Input Stok Harian'),

      ),
      // Jika sudah completed, tampilkan Completion View
      // Jika belum, tampilkan Form Input
      body: isCompleted ? _buildCompletionView() : _buildInputForm(),

      // Tombol "Simpan" sticky di bawah
      bottomNavigationBar: isCompleted
          ? null
          : Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _saveStockData();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.brown,  // Warna coklat
            foregroundColor: Colors.white,   // Teks putih
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Simpan',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Card di bagian atas (tidak sticky, ikut scroll)
            Card(
              color: Colors.brown.shade50,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.assignment,
                      size: 48,
                      color: Colors.brown,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Input Stok Harian',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Silahkan masukkan data stok dan restock hari ini',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            // Daftar produk
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: products.entries.map((entry) {
                  return _buildProductInputCard(
                    productId: entry.key,
                    productData: entry.value,
                    inputData: inputData[entry.key]!,
                  );
                }).toList(),
              ),
            ),
            // Catatan: Tombol Simpan dipindahkan ke bottomNavigationBar
            const SizedBox(height: 80), // beri jarak supaya konten tidak tertutup
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 120,
              color: Colors.green.shade600,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Selesai!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Anda telah menyelesaikan input stok harian',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                // Izinkan edit lagi
                _saveCompletedStatus(false);
              },
              icon: const Icon(Icons.edit),
              label: const Text(
                'Edit Log Harian',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown, // Warna coklat
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInputCard({
    required String productId,
    required Map<String, dynamic> productData,
    required Map<String, dynamic> inputData,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nama produk + ikon
            Row(
              children: [
                const Icon(Icons.local_cafe, color: Colors.brown, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productData['nama'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Harga Jual: Rp ${NumberFormat('#,###').format(productData['hargaJual'])}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Input stok
            _buildInputField(
              label: 'Stok',
              hint: 'Masukkan stok',
              initialValue: inputData['stok'],
              isRequired: true, // stok wajib diisi
              onChanged: (value) {
                inputData['stok'] = value;
              },
            ),
            const SizedBox(height: 16),

            // Input restock (opsional)
            _buildInputField(
              label: 'Restock',
              hint: 'Masukkan restock (opsional)',
              initialValue: inputData['restock'],
              isRequired: false,
              onChanged: (value) {
                inputData['restock'] = value;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required String? initialValue,
    required ValueChanged<String> onChanged,
    required bool isRequired,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      validator: (value) {
        if (isRequired && (value == null || value.isEmpty)) {
          return 'Field ini tidak boleh kosong';
        }
        return null;
      },
    );
  }
}
