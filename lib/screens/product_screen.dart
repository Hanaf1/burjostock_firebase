import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'Analisis/analysis_screen.dart';
import 'categoryManagementScreen.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({Key? key}) : super(key: key);

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Map<String, dynamic> productsData = {};
  Map<String, int> productStocks = {};
  String bestProduct = '-';
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String? statusFilter; // null = semua, "Aman", "Menipis", "Habis"

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUserRole();
  }

  String userRole = ""; // misalnya kosong di awal

  final user = FirebaseAuth.instance.currentUser;

  Future<void> _loadData() async {
    // Ambil data produk dari node "products"
    final productsSnapshot = await _db.child("products").get();
    if (productsSnapshot.value != null && productsSnapshot.value is Map) {
      setState(() {
        productsData =
        Map<String, dynamic>.from(productsSnapshot.value as Map);
      });
    }

    // Format tanggal hari ini dan kemarin
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String yesterdayStr = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    // Ambil data stok hari ini dan kemarin
    final stokTodaySnapshot =
    await _db.child("stok_harian").child(todayStr).get();
    final stokYesterdaySnapshot =
    await _db.child("stok_harian").child(yesterdayStr).get();

    Map<String, dynamic> todayData = {};
    Map<String, dynamic> yesterdayData = {};

    if (stokTodaySnapshot.value != null && stokTodaySnapshot.value is Map) {
      todayData = Map<String, dynamic>.from(stokTodaySnapshot.value as Map);
    }
    if (stokYesterdaySnapshot.value != null &&
        stokYesterdaySnapshot.value is Map) {
      yesterdayData =
      Map<String, dynamic>.from(stokYesterdaySnapshot.value as Map);
    }

    productStocks.clear();
    for (var key in productsData.keys) {
      if (todayData.containsKey(key)) {
        productStocks[key] = todayData[key]['stok'] ?? 0;
      } else if (yesterdayData.containsKey(key)) {
        productStocks[key] = yesterdayData[key]['stok'] ?? 0;
      }
    }

    // Ambil data penjualan untuk menentukan produk terlaris
    Map<String, dynamic> salesData = {};
    final salesTodaySnapshot =
    await _db.child("laporan_harian").child(todayStr).get();
    if (salesTodaySnapshot.value != null && salesTodaySnapshot.value is Map) {
      salesData =
      Map<String, dynamic>.from(salesTodaySnapshot.value as Map);
    } else {
      final salesYesterdaySnapshot =
      await _db.child("laporan_harian").child(yesterdayStr).get();
      if (salesYesterdaySnapshot.value != null &&
          salesYesterdaySnapshot.value is Map) {
        salesData =
        Map<String, dynamic>.from(salesYesterdaySnapshot.value as Map);
      }
    }

    // Hitung produk terlaris berdasarkan "laku"
    int maxSales = -1;
    String bestProdId = '';
    salesData.forEach((prodId, data) {
      if (data is Map && data.containsKey('laku')) {
        int sales = data['laku'] ?? 0;
        if (sales > maxSales) {
          maxSales = sales;
          bestProdId = prodId;
        }
      }
    });
    if (bestProdId.isNotEmpty && productsData.containsKey(bestProdId)) {
      bestProduct = productsData[bestProdId]['nama'] ?? '-';
    } else {
      bestProduct = '-';
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Belum login atau user null, atur userRole ke "NONE" atau semacamnya
        setState(() {
          userRole = "NONE";
        });
        return;
      }

      // Ambil role dari path "users/[uid]/role"
      final roleSnap = await _db.child('users/${user.uid}/role').get();

      if (roleSnap.exists && roleSnap.value != null) {
        setState(() {
          userRole = roleSnap.value.toString();
          // misal "KARYAWAN" atau "PEMILIK"
        });
      } else {
        // Jika data tidak ada
        setState(() {
          userRole = "NONE";
        });
      }
    } catch (e) {
      debugPrint("Error loadUserRole: $e");
    }
  }

  bool _isPemilik() {
    // Normalize and compare role to avoid issues with whitespace or case
    String normalizedRole = userRole.trim().toUpperCase();
    // Remove any quotes that might be in the string
    normalizedRole = normalizedRole.replaceAll('"', '');

    return normalizedRole == "PEMILIK";
  }

  // Fungsi CRUD: Dialog untuk menambah/mengedit produk
  // Pada _showProductDialog, tambahkan dropdown kategori

  void _showProductDialog({String? productId, Map? productData}) {
    final _namaController = TextEditingController(text: productData?['nama'] ?? '');
    final _hargaBeliController = TextEditingController(
        text: productData?['hargaBeli']?.toString() ?? '');
    final _hargaJualController = TextEditingController(
        text: productData?['hargaJual']?.toString() ?? '');

    // Nilai awal kategori yang dipilih
    String? selectedCategoryId = productData?['categoryId'];
    Map<String, dynamic> categories = {};

    // Fungsi untuk memuat daftar kategori
    Future<void> loadCategories() async {
      final snapshot = await _db.child("categories").get();
      if (snapshot.value != null && snapshot.value is Map) {
        categories = Map<String, dynamic>.from(snapshot.value as Map);
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // StatefulBuilder untuk memperbarui state dialog

            // Muat kategori saat dialog dibuka
            if (categories.isEmpty) {
              loadCategories().then((_) {
                setState(() {}); // Refresh dialog saat kategori sudah dimuat
              });
            }

            return AlertDialog(
              title: Text(productId == null ? 'Tambah Produk' : 'Edit Produk'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _namaController,
                      decoration: const InputDecoration(labelText: 'Nama'),
                    ),
                    TextField(
                      controller: _hargaBeliController,
                      decoration: const InputDecoration(labelText: 'Harga Beli'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: _hargaJualController,
                      decoration: const InputDecoration(labelText: 'Harga Jual'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Dropdown untuk kategori
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedCategoryId,
                      hint: const Text('Pilih Kategori'),
                      isExpanded: true,
                      items: [
                        // Tambahkan opsi untuk semua kategori
                        ...categories.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value['nama']),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedCategoryId = value;
                        });
                      },
                    ),

                    // Tombol untuk mengelola kategori
                    if (categories.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else
                      TextButton.icon(
                        onPressed: () {
                          // Tutup dialog saat ini
                          Navigator.of(context).pop();

                          // Buka halaman manajemen kategori
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CategoryManagementScreen(),
                            ),
                          ).then((_) {
                            // Buka kembali dialog produk setelah kembali dari manajemen kategori
                            _showProductDialog(
                              productId: productId,
                              productData: productData,
                            );
                          });
                        },
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Kelola Kategori'),
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
                    String nama = _namaController.text;
                    int hargaBeli = int.tryParse(_hargaBeliController.text) ?? 0;
                    int hargaJual = int.tryParse(_hargaJualController.text) ?? 0;

                    // Validasi
                    if (nama.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama produk tidak boleh kosong')),
                      );
                      return;
                    }

                    if (selectedCategoryId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pilih kategori terlebih dahulu')),
                      );
                      return;
                    }

                    Map<String, dynamic> newProduct = {
                      'nama': nama,
                      'hargaBeli': hargaBeli,
                      'hargaJual': hargaJual,
                      'categoryId': selectedCategoryId,
                    };

                    if (productId == null) {
                      // Tambah produk baru
                      DatabaseReference newRef = _db.child("products").push();
                      await newRef.set(newProduct);
                    } else {
                      // Update produk yang sudah ada
                      await _db.child("products").child(productId).update(newProduct);
                    }

                    Navigator.of(context).pop();
                    _loadData();
                  },
                  child: Text(productId == null ? 'Tambah' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Fungsi CRUD: Menghapus produk
  Future<void> _deleteProduct(String productId) async {
    await _db.child("products").child(productId).remove();
    _loadData();
  }

  Widget _buildStatusBadge(int stock) {
    String label;
    Color color;
    if (stock <= 0) {
      label = 'Habis';
      color = Colors.red;
    } else if (stock <= 5) {
      label = 'Menipis';
      color = Colors.orange;
    } else {
      label = 'Aman';
      color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Mendapatkan status stok dari jumlah stok
  String _getStockStatus(int stock) {
    if (stock <= 0) {
      return "Habis";
    } else if (stock <= 5) {
      return "Menipis";
    } else {
      return "Aman";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    bool isPemilik = _isPemilik();

    // Ambil produk low stock (stok < 30)
    final allLowStockProducts = productsData.entries
        .where((entry) =>
    productStocks.containsKey(entry.key) &&
        (productStocks[entry.key] ?? 0) <= 5)
        .map((entry) => {
      'id': entry.key,
      'nama': entry.value['nama'],
      'stok': productStocks[entry.key] ?? 0,
    })
        .toList();

    // Jika lebih dari 2, tampilkan 2 produk dan tambahan "dan X lainnya"
    List<Map<String, dynamic>> displayedLowStock;
    int extraCount = 0;
    if (allLowStockProducts.length > 2) {
      displayedLowStock = allLowStockProducts.take(2).toList();
      extraCount = allLowStockProducts.length - 2;
    } else {
      displayedLowStock = allLowStockProducts;
    }

    // Filter produk berdasarkan query search dan status stok
    final filteredProducts = productsData.entries.where((entry) {
      String productName = entry.value['nama'].toString().toLowerCase();
      int stock = productStocks[entry.key] ?? 0;
      String stockStatus = _getStockStatus(stock);

      // Filter berdasarkan nama produk
      bool matchesSearch = searchQuery.isEmpty || productName.contains(searchQuery);

      // Filter berdasarkan status stok (jika filter aktif)
      bool matchesStatus = statusFilter == null || stockStatus == statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],

      floatingActionButton: isPemilik ? FloatingActionButton(
        onPressed: () => _showProductDialog(),
        child: const Icon(Icons.add),
      ) : null,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Product',
                style: GoogleFonts.poppins(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  color: Colors.black,
                ),
              ),
            ),
            SizedBox(height: 10,),

            // Kondisional card analisis produk - hanya tampil jika PEMILIK
            if (isPemilik)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnalyticScreen(), // Buat screen baru untuk analytics
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Bagian kiri - Informasi
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Analisis Produk",
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Pantau performa & pendapatan produk",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  // Total Produk
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.inventory_2_outlined,
                                          size: 16,
                                          color: Colors.blue[700],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${productsData.length} Produk",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Total Low Stock
                                  if (allLowStockProducts.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.warning_outlined,
                                            size: 16,
                                            color: Colors.red[700],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${allLowStockProducts.length} Menipis",
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.red[700],
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
                        // Bagian kanan - Icon dan arrow
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF63B4FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.analytics_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            // Search Bar dengan filter status stok
            Column(
              children: [
                TextField(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                  ),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari produk...' ,
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        setState(() {
                          searchQuery =
                              _searchController.text.trim().toLowerCase();
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.trim().toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Filter chip untuk status stok
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Semua',
                          style: TextStyle(
                              fontFamily: 'Poppins'
                          ),),
                        selected: statusFilter == null,
                        onSelected: (selected) {
                          setState(() {
                            statusFilter = null;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.blue[100],
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Aman',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                          ),
                        ),
                        selected: statusFilter == 'Aman',
                        onSelected: (selected) {
                          setState(() {
                            statusFilter = selected ? 'Aman' : null;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.green[100],
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Menipis', style:
                        TextStyle(
                          fontFamily: 'Poppins',
                        ),),
                        selected: statusFilter == 'Menipis',
                        onSelected: (selected) {
                          setState(() {
                            statusFilter = selected ? 'Menipis' : null;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.orange[100],
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Habis',
                          style: TextStyle(
                              fontFamily: 'Poppins'
                          ),),
                        selected: statusFilter == 'Habis',
                        onSelected: (selected) {
                          setState(() {
                            statusFilter = selected ? 'Habis' : null;
                          });
                        },
                        backgroundColor: Colors.grey[200],
                        selectedColor: Colors.red[100],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Daftar Produk dengan CRUD (filtered berdasarkan search dan status)
            ...filteredProducts.map((entry) {
              final product = entry.value;
              final productId = entry.key;
              final stock = productStocks[productId] ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              product['nama'],
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildStatusBadge(stock),
                          // Tampilkan tombol edit dan delete hanya untuk PEMILIK
                          if (isPemilik) ...[
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showProductDialog(
                                  productId: productId, productData: product),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProduct(productId),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Stok: $stock items",
                            style: const TextStyle(color: Colors.grey),
                          ),
                          // Harga beli hanya tampil untuk PEMILIK
                          if (isPemilik)
                            Text(
                              "Harga Beli: Rp${NumberFormat('#,###').format(product['hargaBeli'])}",
                              style: const TextStyle(color: Colors.grey),
                            ),
                          Text(
                            "Harga Jual: Rp${NumberFormat('#,###').format(product['hargaJual'])}",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
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