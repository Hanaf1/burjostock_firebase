import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryManager extends StatefulWidget {
  final Function onCategoriesUpdated;
  final Map<String, dynamic> initialCategories;
  final Map<String, dynamic> productsData;

  const CategoryManager({
    Key? key,
    required this.onCategoriesUpdated,
    required this.initialCategories,
    required this.productsData,
  }) : super(key: key);

  @override
  State<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<CategoryManager> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final _categoryController = TextEditingController();
  late Map<String, dynamic> categoriesData;

  @override
  void initState() {
    super.initState();
    categoriesData = Map<String, dynamic>.from(widget.initialCategories);
  }

  Future<void> _loadCategories() async {
    final snapshot = await _db.child("categories").get();
    if (snapshot.value != null && snapshot.value is Map) {
      setState(() {
        categoriesData = Map<String, dynamic>.from(snapshot.value as Map);
      });
      widget.onCategoriesUpdated(categoriesData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Kelola Kategori',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Form tambah kategori baru
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tambah Kategori Baru",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _categoryController,
                            decoration: InputDecoration(
                              labelText: 'Nama Kategori',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            String nama = _categoryController.text.trim();
                            if (nama.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nama kategori tidak boleh kosong')),
                              );
                              return;
                            }

                            Map<String, dynamic> newCategory = {
                              'nama': nama,
                            };

                            // Tambah kategori baru
                            DatabaseReference newRef = _db.child("categories").push();
                            await newRef.set(newCategory);

                            // Clear text field
                            _categoryController.clear();

                            // Reload kategori
                            await _loadCategories();

                            // Tampilkan notifikasi sukses
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kategori berhasil ditambahkan'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Tambah'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Daftar kategori
            Expanded(
              child: categoriesData.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.category_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada kategori',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: categoriesData.length,
                itemBuilder: (context, index) {
                  final entry = categoriesData.entries.elementAt(index);
                  final categoryId = entry.key;
                  final category = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        category['nama'],
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit kategori
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              _showEditCategoryDialog(
                                categoryId: categoryId,
                                categoryData: category,
                              );
                            },
                          ),
                          // Hapus kategori
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _showDeleteCategoryConfirmation(
                                categoryId: categoryId,
                                categoryName: category['nama'],
                              );
                            },
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
      ),
    );
  }

  // Dialog konfirmasi hapus kategori - Versi yang diperbarui
  void _showDeleteCategoryConfirmation({required String categoryId, required String categoryName}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: Text('Yakin ingin menghapus kategori "$categoryName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // Cek apakah kategori sedang digunakan oleh produk
                bool isUsed = false;
                List<String> affectedProducts = [];

                widget.productsData.forEach((key, value) {
                  if (value is Map && value.containsKey('categoryId') && value['categoryId'] == categoryId) {
                    isUsed = true;
                    // Tambahkan nama produk ke daftar produk yang terpengaruh
                    if (value.containsKey('nama')) {
                      affectedProducts.add(value['nama']);
                    }
                  }
                });

                if (isUsed) {
                  // Tutup dialog konfirmasi pertama
                  Navigator.of(context).pop();

                  // Tampilkan dialog konfirmasi lanjutan
                  _showForceDeleteConfirmation(
                    categoryId: categoryId,
                    categoryName: categoryName,
                    affectedProducts: affectedProducts,
                  );
                  return;
                }

                // Jika tidak digunakan, langsung hapus kategori
                await _db.child("categories").child(categoryId).remove();

                // Refresh data
                await _loadCategories();

                // Tampilkan notifikasi sukses
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kategori berhasil dihapus'),
                    backgroundColor: Colors.green,
                  ),
                );

                Navigator.of(context).pop();
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  // Dialog konfirmasi paksa hapus kategori yang sedang digunakan
  void _showForceDeleteConfirmation({
    required String categoryId,
    required String categoryName,
    required List<String> affectedProducts,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Perhatian!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kategori "$categoryName" sedang digunakan oleh ${affectedProducts.length} produk:'),
              const SizedBox(height: 8),
              // Menampilkan daftar produk yang menggunakan kategori ini
              Container(
                constraints: BoxConstraints(
                  maxHeight: 120, // Batasi tinggi daftar
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: affectedProducts.length > 5
                      ? 5 // Tampilkan maks 5 produk
                      : affectedProducts.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${affectedProducts[index]}'),
                    );
                  },
                ),
              ),
              // Tampilkan "dan X lainnya" jika produk lebih dari 5
              if (affectedProducts.length > 5)
                Text('• ... dan ${affectedProducts.length - 5} produk lainnya'),
              const SizedBox(height: 16),
              const Text(
                'Jika Anda menghapus kategori ini, semua produk tersebut akan kehilangan referensi kategori.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Apakah Anda yakin ingin melanjutkan?',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                // Hapus kategori meskipun sedang digunakan
                await _db.child("categories").child(categoryId).remove();

                // Update produk yang menggunakan kategori ini
                // Hapus referensi categoryId dari produk
                for (var entry in widget.productsData.entries) {
                  String productId = entry.key;
                  var product = entry.value;
                  if (product is Map &&
                      product.containsKey('categoryId') &&
                      product['categoryId'] == categoryId) {
                    await _db.child("products").child(productId).update({
                      'categoryId': null, // Atau bisa dihapus sepenuhnya jika diinginkan
                    });
                  }
                }

                // Refresh data
                await _loadCategories();

                // Tampilkan notifikasi sukses
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kategori berhasil dihapus'),
                    backgroundColor: Colors.green,
                  ),
                );

                Navigator.of(context).pop();
              },
              child: const Text('Hapus Paksa'),
            ),
          ],
        );
      },
    );
  }

  // Dialog untuk mengedit kategori
  void _showEditCategoryDialog({required String categoryId, required Map categoryData}) {
    final _categoryNameController = TextEditingController(text: categoryData['nama']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Kategori'),
          content: TextField(
            controller: _categoryNameController,
            decoration: const InputDecoration(
              labelText: 'Nama Kategori',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                String nama = _categoryNameController.text.trim();
                if (nama.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama kategori tidak boleh kosong')),
                  );
                  return;
                }

                // Update kategori
                await _db.child("categories").child(categoryId).update({'nama': nama});

                // Refresh data
                await _loadCategories();

                // Tampilkan notifikasi sukses
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Kategori berhasil diperbarui'),
                    backgroundColor: Colors.green,
                  ),
                );

                Navigator.of(context).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}