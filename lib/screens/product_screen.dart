import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import 'Analisis/analysis_screen.dart';
import 'categoryManagementScreen.dart';
import 'edit_product_screen.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({Key? key}) : super(key: key);

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Map<String, dynamic> productsData = {};
  Map<String, dynamic> categoriesData = {}; // Untuk menyimpan data kategori
  Map<String, int> productStocks = {};

  // Tambahkan variabel subscription
  StreamSubscription? _productsSubscription;
  StreamSubscription? _categoriesSubscription;
  StreamSubscription? _stokHarianSubscription;
  StreamSubscription? _laporanHarianSubscription;

  String? categoryFilter;
  String bestProduct = '-';
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";
  String? statusFilter; // null = semua, "Aman", "Menipis", "Habis"

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealTimeListeners();
    _loadUserRole();
  }

  String userRole = ""; // kosong di awal

  final user = FirebaseAuth.instance.currentUser;

  Future<void> _loadData() async {
    try {
      // Ambil data produk dari node "products"
      final productsSnapshot = await _db.child("products").get();
      if (productsSnapshot.value != null && productsSnapshot.value is Map) {
        setState(() {
          productsData = Map<String, dynamic>.from(productsSnapshot.value as Map);
        });
      }

      // Ambil data kategori
      final categoriesSnapshot = await _db.child("categories").get();
      if (categoriesSnapshot.value != null && categoriesSnapshot.value is Map) {
        setState(() {
          categoriesData = Map<String, dynamic>.from(categoriesSnapshot.value as Map);
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
        // Pastikan key adalah String
        if (todayData.containsKey(key)) {
          var stokData = todayData[key];
          if (stokData is Map) {
            var stokValue = stokData['stok'];
            // Konversi ke int jika perlu
            if (stokValue is int) {
              productStocks[key] = stokValue;
            } else if (stokValue is String) {
              try {
                productStocks[key] = int.parse(stokValue);
              } catch (_) {
                productStocks[key] = 0;
              }
            } else {
              productStocks[key] = 0;
            }
          } else {
            productStocks[key] = 0;
          }
        } else if (yesterdayData.containsKey(key)) {
          var stokData = yesterdayData[key];
          if (stokData is Map) {
            var stokValue = stokData['stok'];
            // Konversi ke int jika perlu
            if (stokValue is int) {
              productStocks[key] = stokValue;
            } else if (stokValue is String) {
              try {
                productStocks[key] = int.parse(stokValue);
              } catch (_) {
                productStocks[key] = 0;
              }
            } else {
              productStocks[key] = 0;
            }
          } else {
            productStocks[key] = 0;
          }
        } else {
          productStocks[key] = 0;
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
          var lakuValue = data['laku'];
          int sales = 0;

          if (lakuValue is int) {
            sales = lakuValue;
          } else if (lakuValue is String) {
            try {
              sales = int.parse(lakuValue);
            } catch (_) {
              sales = 0;
            }
          }

          if (sales > maxSales) {
            maxSales = sales;
            bestProdId = prodId;
          }
        }
      });

      if (bestProdId.isNotEmpty && productsData.containsKey(bestProdId)) {
        var product = productsData[bestProdId];
        if (product is Map && product.containsKey('nama')) {
          bestProduct = product['nama'].toString();
        } else {
          bestProduct = '-';
        }
      } else {
        bestProduct = '-';
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error dalam _loadData: $e");
      setState(() {
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

      // Ambil role dari path "users/[uid]/role"
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
    // Normalize and compare role to avoid issues with whitespace or case
    String normalizedRole = userRole.trim().toUpperCase();
    // Remove any quotes that might be in the string
    normalizedRole = normalizedRole.replaceAll('"', '');

    return normalizedRole == "PEMILIK";
  }


  void _setupRealTimeListeners() {
    // Listener untuk products
    _productsSubscription = _db.child("products").onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        setState(() {
          productsData = Map<String, dynamic>.from(event.snapshot.value as Map);
          _updateProductStocks(); // Tambahkan method ini untuk memperbarui stok
        });
      }
    });

    // Listener untuk categories
    _categoriesSubscription = _db.child("categories").onValue.listen((event) {
      if (event.snapshot.value != null && event.snapshot.value is Map) {
        setState(() {
          categoriesData = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });

    // Listener untuk stok harian
    _stokHarianSubscription = _db.child("stok_harian").onValue.listen((event) {
      setState(() {
        _updateProductStocks();
      });
    });

    // Listener untuk laporan harian (untuk produk terlaris)
    _laporanHarianSubscription = _db.child("laporan_harian").onValue.listen((event) {
      setState(() {
        _updateBestProduct();
      });
    });
  }

  void _updateProductStocks() {
    productStocks.clear();

    // Format tanggal hari ini dan kemarin
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String yesterdayStr = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    // Ambil data stok dari hari ini atau kemarin
    var stokData = _db.child("stok_harian").child(todayStr).get();
    var yesterdayStokData = _db.child("stok_harian").child(yesterdayStr).get();

    stokData.then((todaySnapshot) {
      yesterdayStokData.then((yesterdaySnapshot) {
        Map<String, dynamic> todayDataMap = todaySnapshot.value is Map
            ? Map<String, dynamic>.from(todaySnapshot.value as Map)
            : {};

        Map<String, dynamic> yesterdayDataMap = yesterdaySnapshot.value is Map
            ? Map<String, dynamic>.from(yesterdaySnapshot.value as Map)
            : {};

        for (var key in productsData.keys) {
          int stock = 0;

          if (todayDataMap.containsKey(key) && todayDataMap[key] is Map) {
            var stokValue = todayDataMap[key]['stok'];
            stock = _parseStock(stokValue);
          } else if (yesterdayDataMap.containsKey(key) && yesterdayDataMap[key] is Map) {
            var stokValue = yesterdayDataMap[key]['stok'];
            stock = _parseStock(stokValue);
          }

          productStocks[key] = stock;
        }

        setState(() {
          isLoading = false;
        });
      });
    });
  }

  int _parseStock(dynamic stokValue) {
    if (stokValue is int) return stokValue;
    if (stokValue is String) {
      return int.tryParse(stokValue) ?? 0;
    }
    return 0;
  }

  void _updateBestProduct() {
    // Format tanggal hari ini dan kemarin
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String yesterdayStr = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));

    // Ambil data penjualan
    var salesTodayRef = _db.child("laporan_harian").child(todayStr).get();
    var salesYesterdayRef = _db.child("laporan_harian").child(yesterdayStr).get();

    salesTodayRef.then((todaySnapshot) {
      salesYesterdayRef.then((yesterdaySnapshot) {
        Map<String, dynamic> salesData = {};

        if (todaySnapshot.value is Map) {
          salesData = Map<String, dynamic>.from(todaySnapshot.value as Map);
        } else if (yesterdaySnapshot.value is Map) {
          salesData = Map<String, dynamic>.from(yesterdaySnapshot.value as Map);
        }

        // Logika mencari produk terlaris (mirip dengan implementasi sebelumnya)
        int maxSales = -1;
        String bestProdId = '';

        salesData.forEach((prodId, data) {
          if (data is Map && data.containsKey('laku')) {
            var lakuValue = data['laku'];
            int sales = _parseStock(lakuValue);

            if (sales > maxSales) {
              maxSales = sales;
              bestProdId = prodId;
            }
          }
        });

        setState(() {
          if (bestProdId.isNotEmpty && productsData.containsKey(bestProdId)) {
            var product = productsData[bestProdId];
            bestProduct = product is Map && product.containsKey('nama')
                ? product['nama'].toString()
                : '-';
          } else {
            bestProduct = '-';
          }
        });
      });
    });
  }


  // Fungsi untuk membuka layar kelola kategori
  void _openCategoryManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryManager(
          initialCategories: categoriesData,
          productsData: productsData,
          onCategoriesUpdated: (updatedCategories) {
            setState(() {
              categoriesData = updatedCategories;
            });
          },
        ),
      ),
    ).then((_) {
      // Refresh data ketika kembali dari halaman kategori
      _loadData();
    });
  }

  Future<void> _showProductDialog({String? productId, Map<String, dynamic>? productData}) async {
    // Pastikan controller disiapkan tetapi tidak digunakan di beberapa tempat
    TextEditingController namaController = TextEditingController(text: productData?['nama'] ?? '');
    TextEditingController hargaBeliController = TextEditingController(text: productData?['hargaBeli']?.toString() ?? '');
    TextEditingController hargaJualController = TextEditingController(text: productData?['hargaJual']?.toString() ?? '');

    // Variabel untuk menyimpan kategori pilihan
    String? currentCategoryId = productData?['categoryId']?.toString();

    // Gunakan BottomSheet alih-alih Dialog
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Penting agar BottomSheet bisa full tinggi
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext builderContext, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(builderContext).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    productId == null ? 'Tambah Produk' : 'Edit Produk',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),

                  // Nama Produk
                  TextField(
                    controller: namaController,
                    decoration: InputDecoration(
                      labelText: 'Nama Produk',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Harga Beli
                  TextField(
                    controller: hargaBeliController,
                    decoration: InputDecoration(
                      labelText: 'Harga Beli',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 12),

                  // Harga Jual
                  TextField(
                    controller: hargaJualController,
                    decoration: InputDecoration(
                      labelText: 'Harga Jual',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 12),

                  // Kategori Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    value: currentCategoryId,
                    hint: Text('Pilih Kategori'),
                    items: categoriesData.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value['nama'] ?? 'Kategori'),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        currentCategoryId = newValue;
                      });
                    },
                  ),
                  SizedBox(height: 20),

                  // Tombol aksi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(sheetContext); // Tutup bottom sheet
                        },
                        child: Text('Batal'),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Ambil nilai
                          String nama = namaController.text.trim();

                          // Validasi
                          if (nama.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Nama produk tidak boleh kosong')),
                            );
                            return;
                          }

                          // Proses nilai harga beli/jual
                          String hargaBeliText = hargaBeliController.text.trim();
                          String hargaJualText = hargaJualController.text.trim();

                          int hargaBeli = 0;
                          int hargaJual = 0;

                          if (hargaBeliText.isNotEmpty) {
                            hargaBeli = int.tryParse(hargaBeliText) ?? 0;
                          }

                          if (hargaJualText.isNotEmpty) {
                            hargaJual = int.tryParse(hargaJualText) ?? 0;
                          }

                          // Data produk
                          Map<String, dynamic> newProduct = {
                            'nama': nama,
                            'hargaBeli': hargaBeli,
                            'hargaJual': hargaJual,
                            'categoryId': currentCategoryId,
                          };

                          // PENTING: Tutup sheet terlebih dahulu
                          Navigator.pop(sheetContext);

                          // Jalankan operasi Firebase dan refresh data
                          _saveProductData(productId, newProduct);
                        },
                        child: Text(productId == null ? 'Tambah' : 'Simpan'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );

    // Bersihkan controller
    namaController.dispose();
    hargaBeliController.dispose();
    hargaJualController.dispose();
  }

// Method baru untuk memisahkan operasi Firebase dari UI
  void _saveProductData(String? productId, Map<String, dynamic> productData) {
    try {
      if (productId == null) {
        // Tambah produk baru
        _db.child('products').push().set(productData).then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Produk berhasil ditambahkan')),
            );
            // Refresh data setelah delay kecil
            Future.delayed(Duration(milliseconds: 300), () {
              if (mounted) _loadData();
            });
          }
        });
      } else {
        // Update produk yang ada
        _db.child('products').child(productId).update(productData).then((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Produk berhasil diperbarui')),
            );
            // Refresh data setelah delay kecil
            Future.delayed(Duration(milliseconds: 300), () {
              if (mounted) _loadData();
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    }
  }


  // Fungsi CRUD: Menghapus produk
  Future<void> _deleteProduct(String productId) async {
    // Dapatkan nama produk untuk ditampilkan di dialog konfirmasi
    String productName = '';
    if (productsData.containsKey(productId) &&
        productsData[productId] is Map &&
        productsData[productId].containsKey('nama')) {
      productName = productsData[productId]['nama']?.toString() ?? '';
    }

    // Tampilkan dialog konfirmasi
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: Text('Apakah Anda yakin ingin menghapus produk "${productName}"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    // Jika user mengonfirmasi penghapusan
    if (confirm == true) {
      try {
        await _db.child("products").child(productId).remove();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Produk "${productName}" berhasil dihapus')),
        );
        _loadData(); // Refresh data setelah penghapusan
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus produk: $e')),
        );
      }
    }
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
      String productName = entry.value['nama']?.toString().toLowerCase() ?? '';
      int stock = productStocks[entry.key] ?? 0;
      String stockStatus = _getStockStatus(stock);

      // Filter berdasarkan nama produk
      bool matchesSearch = searchQuery.isEmpty || productName.contains(searchQuery);

      // Filter berdasarkan status stok
      bool matchesStatus = statusFilter == null || stockStatus == statusFilter;

      // Filter berdasarkan kategori
      bool matchesCategory = categoryFilter == null ||
          (entry.value.containsKey('categoryId') &&
              entry.value['categoryId'] == categoryFilter);

      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();

    filteredProducts.sort((a, b) {
      bool isFirebaseIdA = a.key.startsWith('-');
      bool isFirebaseIdB = b.key.startsWith('-');

      if (isFirebaseIdA && isFirebaseIdB) {
        return b.key.compareTo(a.key);
      }
      else if (isFirebaseIdA) {
        return -1;
      }
      else if (isFirebaseIdB) {
        return 1;
      }
      else {
        return 0;
      }
    });

    return Scaffold(
        backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Buka halaman tambah produk baru
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditProductScreen(
                productData: {}, // Data kosong untuk produk baru
                categoriesData: categoriesData,
              ),
            ),
          );

          // Cek hasil dari EditProductScreen
          if (result != null && result is Map && result['success'] == true) {
            // Tampilkan pesan berhasil
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? 'Produk berhasil ditambahkan')),
            );

            // Refresh data
            _loadData();
          }
        },
        child: const Icon(Icons.add),
      ),
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
            const SizedBox(height: 10),

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
    builder: (context) => AnalyticScreen(),
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
          const SizedBox(width: 2),
          Text(
          "${productsData.length} Produk",
          style: GoogleFonts.poppins(
          fontSize: 10,
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
                  fontSize: 10,
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
    child: const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
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
    // Card kelola kategori
    Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: _openCategoryManager,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.category, size: 24, color: Colors.blue), // Tambahkan ikon di awal
              const SizedBox(width: 12), // Tambahkan jarak
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Kelola Kategori",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${categoriesData.length} Kategori",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    ),
    const SizedBox(height: 16,),

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
    searchQuery = _searchController.text.trim().toLowerCase();
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
    ),
    ),
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
    label: const Text('Menipis',
    style: TextStyle(
    fontFamily: 'Poppins',
    ),
    ),
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
    ),
    ),
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
    const SizedBox(height: 8),
    SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Stack(
    alignment: Alignment.centerRight,
    children: [
    Row(
    children: [
    // Filter chip "Semua Kategori"
    FilterChip(
    label: const Text(
    'Semua Kategori',
    style: TextStyle(fontFamily: 'Poppins'),
    ),
    selected: categoryFilter == null,
    onSelected: (selected) {
    setState(() {
    categoryFilter = null;
    });
    },
    backgroundColor: Colors.grey[200],
    selectedColor: Colors.blue[100],
    ),
    const SizedBox(width: 8),

    // Filter chip kategori lainnya
    ...categoriesData.entries.map((category) {
    return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
    label: Text(
    category.value['nama']?.toString() ?? 'Kategori',
    style: const TextStyle(fontFamily: 'Poppins'),
    ),
    selected: categoryFilter == category.key,
    onSelected: (selected) {
    setState(() {
    categoryFilter = selected ? category.key : null;
    });
    },
    backgroundColor: Colors.grey[200],
    selectedColor: Colors.green[100],
    ),
    );
    }).toList(),
    ],
    ),
    IgnorePointer(
    child: Container(
    width: 50,
    decoration: BoxDecoration(
    gradient: LinearGradient(
    colors: [
    Colors.white.withOpacity(0),
    Colors.white.withOpacity(0.7)
    ],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    ),
    ),
    child: Center(
    child: Icon(
    Icons.chevron_right,
    color: Colors.grey.shade400,
    size: 20,
    ),
    ),
    ),
    ),
    ],
    ),
    ),
    ],
    ),

    const SizedBox(height: 16),

    ...filteredProducts.map((entry) {
    final product = entry.value;
    final productId = entry.key;
    final stock = productStocks[productId] ?? 0;

    // Dapatkan nama kategori dari data yang sudah dimuat
    String categoryName = 'Tidak diketahui';
    if (product.containsKey('categoryId')) {
    String? categoryId = product['categoryId']?.toString();
    if (categoryId != null &&
    categoriesData.containsKey(categoryId) &&
    categoriesData[categoryId] is Map &&
    categoriesData[categoryId].containsKey('nama')) {
      categoryName = categoriesData[categoryId]['nama']?.toString() ?? 'Tidak diketahui';
    }
    }

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
                    product['nama']?.toString() ?? '',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(stock),
                // Tombol edit yang diperbaiki

                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () async {
                    // Konversi produk ke Map terlebih dahulu
                    Map<String, dynamic> productDataMap = Map<String, dynamic>.from(product as Map);

                    // Buka halaman edit produk
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProductScreen(
                          productId: productId,
                          productData: productDataMap,
                          categoriesData: categoriesData,
                        ),
                      ),
                    );

                    // Cek hasil dari EditProductScreen
                    if (result != null && result is Map && result['success'] == true) {
                      // Tampilkan pesan berhasil
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result['message'] ?? 'Produk berhasil diperbarui')),
                      );

                      // Refresh data
                      _loadData();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteProduct(productId),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.containsKey('categoryId'))
                  Text(
                    "Kategori: $categoryName",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                Text(
                  "Stok: $stock items",
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  "Harga Beli: Rp${NumberFormat('#,###').format(product['hargaBeli'] ?? 0)}",
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  "Harga Jual: Rp${NumberFormat('#,###').format(product['hargaJual'] ?? 0)}",
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

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _categoriesSubscription?.cancel();
    _stokHarianSubscription?.cancel();
    _laporanHarianSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}