import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({Key? key}) : super(key: key);

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  // Referensi ke node 'products' di Firebase
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Menyimpan data produk (id → {nama, hargaBeli, hargaJual})
  Map<String, dynamic> productsData = {};

  // Menyimpan data laporan penjualan (misalnya ringkasan penjualan hari ini)
  Map<String, dynamic> reportData = {};

  bool isLoading = true;

  // Controllers untuk dialog tambah/edit produk
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _hargaBeliController = TextEditingController();
  final TextEditingController _hargaJualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Ambil data produk dan laporan_harian untuk hari ini
  Future<void> _loadData() async {
    try {
      setState(() => isLoading = true);

      // Ambil data produk dari node 'products'
      final productsSnap = await _db.child('products').get();
      if (productsSnap.exists && productsSnap.value != null) {
        productsData =
        Map<String, dynamic>.from(productsSnap.value as Map<dynamic, dynamic>);
      }

      // Ambil data laporan_harian untuk hari ini
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final laporanRef = _db.child('laporan_harian').child(today);
      final laporanSnap = await laporanRef.get();

      if (laporanSnap.exists && laporanSnap.value != null) {
        final raw =
        Map<String, dynamic>.from(laporanSnap.value as Map<dynamic, dynamic>);

        int totalOmset = 0;
        int totalLaba = 0;
        int totalItems = 0;
        String bestProductName = '-';
        int maxSold = 0;

        raw.forEach((productId, detail) {
          if (detail != null) {
            final detailMap =
            Map<String, dynamic>.from(detail as Map<dynamic, dynamic>);
            final int omsetVal = (detailMap['omset'] as num?)?.toInt() ?? 0;
            final int labaVal = (detailMap['laba'] as num?)?.toInt() ?? 0;
            final int lakuVal = (detailMap['laku'] as num?)?.toInt() ?? 0;

            totalOmset += omsetVal;
            totalLaba += labaVal;
            totalItems += lakuVal;

            if (lakuVal > maxSold) {
              maxSold = lakuVal;
              bestProductName =
                  productsData[productId]?['nama'] ?? productId;
            }
          }
        });

        reportData = {
          "totalOmset": totalOmset,
          "totalLaba": totalLaba,
          "totalItems": totalItems,
          "bestProductName": bestProductName,
        };
      } else {
        reportData = {
          "totalOmset": 0,
          "totalLaba": 0,
          "totalItems": 0,
          "bestProductName": "-",
        };
      }
    } catch (e) {
      debugPrint("Error _loadData: $e");
      reportData = {
        "totalOmset": 0,
        "totalLaba": 0,
        "totalItems": 0,
        "bestProductName": "-",
      };
    } finally {
      setState(() => isLoading = false);
    }
  }

  /// Tampilkan dialog untuk tambah/edit produk
  Future<void> _showProductDialog({String? productId}) async {
    if (productId != null) {
      // Jika edit, isi field dengan data produk
      final product = productsData[productId] as Map<dynamic, dynamic>;
      _namaController.text = product["nama"].toString();
      _hargaBeliController.text = product["hargaBeli"].toString();
      _hargaJualController.text = product["hargaJual"].toString();
    } else {
      _namaController.clear();
      _hargaBeliController.clear();
      _hargaJualController.clear();
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(productId == null ? 'Tambah Produk' : 'Edit Produk'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _namaController,
                  decoration: const InputDecoration(labelText: 'Nama Produk'),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Nama harus diisi' : null,
                ),
                TextFormField(
                  controller: _hargaBeliController,
                  decoration: const InputDecoration(labelText: 'Harga Beli'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Harga Beli harus diisi'
                      : null,
                ),
                TextFormField(
                  controller: _hargaJualController,
                  decoration: const InputDecoration(labelText: 'Harga Jual'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Harga Jual harus diisi'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                if (productId == null) {
                  // Tambah produk baru
                  String newKey = _db.child('products').push().key ?? "";
                  await _db.child('products').child(newKey).set({
                    "nama": _namaController.text,
                    "hargaBeli": int.parse(_hargaBeliController.text),
                    "hargaJual": int.parse(_hargaJualController.text),
                  });
                } else {
                  // Update produk yang ada
                  await _db.child('products').child(productId).update({
                    "nama": _namaController.text,
                    "hargaBeli": int.parse(_hargaBeliController.text),
                    "hargaJual": int.parse(_hargaJualController.text),
                  });
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  /// Hapus produk dengan konfirmasi
  Future<void> _deleteProduct(String productId) async {
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus produk ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmDelete == true) {
      await _db.child('products').child(productId).remove();
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
        title: const Text("Produk Burjo"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 16),
              _buildProductList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final NumberFormat fmt = NumberFormat('#,##0');
    final int totalOmset = reportData["totalOmset"] ?? 0;
    final int totalLaba = reportData["totalLaba"] ?? 0;
    final int totalItems = reportData["totalItems"] ?? 0;
    final String bestProduct = reportData["bestProductName"] ?? "-";

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Penjualan Hari Ini',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildInfoChip(
                  label: 'Omset',
                  value: 'Rp ${fmt.format(totalOmset)}',
                  icon: Icons.attach_money,
                  iconColor: Colors.blue,
                ),
                _buildInfoChip(
                  label: 'Laba',
                  value: 'Rp ${fmt.format(totalLaba)}',
                  icon: Icons.trending_up,
                  iconColor: Colors.green,
                ),
                _buildInfoChip(
                  label: 'Total Penjualan',
                  value: '$totalItems items',
                  icon: Icons.shopping_cart,
                  iconColor: Colors.orange,
                ),
                _buildInfoChip(
                  label: 'Produk Terlaris',
                  value: bestProduct,
                  icon: Icons.star,
                  iconColor: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: productsData.length,
      itemBuilder: (context, index) {
        final productId = productsData.keys.elementAt(index);
        final product = productsData[productId] as Map;
        return Card(
          child: ListTile(
            title: Text(product["nama"]),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Harga Beli: Rp${product["hargaBeli"]}"),
                Text("Harga Jual: Rp${product["hargaJual"]}"),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showProductDialog(productId: productId),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteProduct(productId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    super.dispose();
  }
}
