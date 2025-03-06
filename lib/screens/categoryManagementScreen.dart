import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  Map<String, dynamic> categoriesData = {};
  bool isLoading = true;
  String userRole = "";

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserRole();
  }

  Future<void> _loadData() async {
    // Ambil data kategori dari node "categories"
    final categoriesSnapshot = await _db.child("categories").get();
    if (categoriesSnapshot.value != null && categoriesSnapshot.value is Map) {
      setState(() {
        categoriesData = Map<String, dynamic>.from(categoriesSnapshot.value as Map);
        isLoading = false;
      });
    } else {
      setState(() {
        categoriesData = {};
        isLoading = false;
      });
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          userRole = "NONE";
        });
        return;
      }

      final roleSnap = await _db.child('users/${user.uid}/role').get();

      if (roleSnap.exists && roleSnap.value != null) {
        setState(() {
          userRole = roleSnap.value.toString();
        });
      } else {
        setState(() {
          userRole = "NONE";
        });
      }
    } catch (e) {
      debugPrint("Error loadUserRole: $e");
    }
  }

  bool _isPemilik() {
    String normalizedRole = userRole.trim().toUpperCase();
    normalizedRole = normalizedRole.replaceAll('"', '');
    return normalizedRole == "PEMILIK";
  }

  // Dialog untuk menambah atau mengedit kategori
  void _showCategoryDialog({String? categoryId, Map? categoryData}) {
    final _namaController = TextEditingController(text: categoryData?['nama'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(categoryId == null ? 'Tambah Kategori' : 'Edit Kategori'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _namaController,
                  decoration: const InputDecoration(labelText: 'Nama Kategori'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                String nama = _namaController.text.trim();
                if (nama.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama kategori tidak boleh kosong')),
                  );
                  return;
                }

                Map<String, dynamic> newCategory = {
                  'nama': nama,
                };

                if (categoryId == null) {
                  // Tambah kategori baru
                  DatabaseReference newRef = _db.child("categories").push();
                  await newRef.set(newCategory);
                } else {
                  // Update kategori yang sudah ada
                  await _db.child("categories").child(categoryId).update(newCategory);
                }

                Navigator.of(context).pop();
                _loadData(); // Reload data setelah perubahan
              },
              child: Text(categoryId == null ? 'Tambah' : 'Update'),
            ),
          ],
        );
      },
    );
  }

  // Fungsi untuk menghapus kategori
  Future<void> _deleteCategory(String categoryId) async {
    // Cek apakah kategori sedang digunakan oleh produk
    final productsSnapshot = await _db.child("products").get();
    if (productsSnapshot.value != null && productsSnapshot.value is Map) {
      Map<String, dynamic> productsData = Map<String, dynamic>.from(productsSnapshot.value as Map);

      // Cek jika ada produk yang menggunakan kategori ini
      bool isUsed = productsData.values.any((product) {
        if (product is Map && product.containsKey('categoryId')) {
          return product['categoryId'] == categoryId;
        }
        return false;
      });

      if (isUsed) {
        // Tampilkan peringatan bahwa kategori sedang digunakan
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori ini sedang digunakan oleh beberapa produk. Ubah kategori produk terlebih dahulu.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Jika tidak digunakan, hapus kategori
    await _db.child("categories").child(categoryId).remove();
    _loadData(); // Reload data setelah perubahan
  }

  // Dialog konfirmasi hapus kategori
  void _showDeleteConfirmation(String categoryId, String categoryName) {
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
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCategory(categoryId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    bool isPemilik = _isPemilik();

    // Jika bukan pemilik, redirect ke halaman lain atau tampilkan pesan
    if (!isPemilik) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kategori')),
        body: const Center(
          child: Text('Anda tidak memiliki akses ke halaman ini.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manajemen Kategori',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: categoriesData.isEmpty
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Belum ada kategori',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Kategori'),
              ),
            ],
          ),
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Total Kategori: ${categoriesData.length}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ...categoriesData.entries.map((entry) {
              final category = entry.value;
              final categoryId = entry.key;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  title: Text(
                    category['nama'],
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'ID: $categoryId',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showCategoryDialog(
                          categoryId: categoryId,
                          categoryData: category,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmation(
                          categoryId,
                          category['nama'],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}