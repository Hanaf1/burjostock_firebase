import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class EditProductScreen extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic> productData;
  final Map<String, dynamic> categoriesData;

  const EditProductScreen({
    Key? key,
    this.productId,
    required this.productData,
    required this.categoriesData,
  }) : super(key: key);

  @override
  _EditProductScreenState createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _hargaBeliController;
  late TextEditingController _hargaJualController;
  String? _selectedCategoryId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.productData['nama'] ?? '');
    _hargaBeliController = TextEditingController(text: widget.productData['hargaBeli']?.toString() ?? '');
    _hargaJualController = TextEditingController(text: widget.productData['hargaJual']?.toString() ?? '');
    _selectedCategoryId = widget.productData['categoryId'];
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isNewProduct = widget.productId == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNewProduct ? 'Tambah Produk' : 'Edit Produk'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _namaController,
              decoration: InputDecoration(
                labelText: 'Nama Produk',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama produk tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _hargaBeliController,
              decoration: InputDecoration(
                labelText: 'Harga Beli',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _hargaJualController,
              decoration: InputDecoration(
                labelText: 'Harga Jual',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              value: _selectedCategoryId,
              hint: Text('Pilih Kategori'),
              items: widget.categoriesData.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value['nama'] ?? 'Kategori'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategoryId = value;
                });
              },
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveProduct,
              child: Text(isNewProduct ? 'Tambah' : 'Simpan'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Ambil nilai
    String nama = _namaController.text.trim();

    // Parse values safely
    String hargaBeliString = _hargaBeliController.text.trim();
    String hargaJualString = _hargaJualController.text.trim();

    int hargaBeli = int.tryParse(hargaBeliString) ?? 0;
    int hargaJual = int.tryParse(hargaJualString) ?? 0;

    // Prepare data
    Map<String, dynamic> productData = {
      'nama': nama,
      'hargaBeli': hargaBeli,
      'hargaJual': hargaJual,
      'categoryId': _selectedCategoryId,
    };

    try {
      final DatabaseReference db = FirebaseDatabase.instance.ref();
      if (widget.productId == null) {
        // Add new product
        await db.child('products').push().set(productData);
      } else {
        // Update existing product
        await db.child('products').child(widget.productId!).update(productData);
      }

      // Return success
      Navigator.pop(context, true);
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

}