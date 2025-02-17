import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/stock.dart';
import '../models/product.dart';

class DatabaseHelper {
  static Database? _database;
  static final DatabaseHelper instance = DatabaseHelper._init();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('burjostock.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE product (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        harga_beli REAL NOT NULL,
        harga_jual REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        stok_awal INTEGER NOT NULL,
        stok_beli INTEGER DEFAULT 0,
        stok_terjual INTEGER DEFAULT 0,
        stok_sisa INTEGER DEFAULT 0,
        tanggal DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES product (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE keuangan_harian (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        modal REAL DEFAULT 0,
        omset REAL DEFAULT 0,
        laba REAL DEFAULT 0,
        tanggal DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (product_id) REFERENCES product (id)
      )
    ''');
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('product', product.toMap());
  }

  Future<int> insertStock(Stock stock) async {
    final db = await database;
    final batch = db.batch();

    try {
      final stockData = {
        'product_id': stock.productId,
        'stok_awal': stock.stokAwal,
        'stok_beli': stock.stokBeli,
        'stok_terjual': stock.stokTerjual,
        'stok_sisa': stock.stokSisa,
        'tanggal': DateTime.now().toIso8601String().split('.')[0], // Format DATETIME
      };
      batch.insert('stock', stockData);

      final keuanganData = {
        'product_id': stock.productId,
        'modal': stock.stokTerjual * (stock.product?.hargaBeli ?? 0),
        'omset': stock.stokTerjual * (stock.product?.hargaJual ?? 0),
        'laba': (stock.stokTerjual * (stock.product?.hargaJual ?? 0)) -
            (stock.stokTerjual * (stock.product?.hargaBeli ?? 0)),
        'tanggal': DateTime.now().toIso8601String().split('.')[0], // Format DATETIME
      };
      batch.insert('keuangan_harian', keuanganData);

      final results = await batch.commit();
      return results[0] as int;
    } catch (e) {
      print('Error inserting stock: $e');
      return -1;
    }
  }

  Future<List<Stock>> getStocksByDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT 
        s.*,
        p.nama as nama_product,
        p.harga_beli,
        p.harga_jual,
        k.modal,
        k.omset,
        k.laba
      FROM stock s
      JOIN product p ON s.product_id = p.id
      LEFT JOIN keuangan_harian k ON s.product_id = k.product_id 
        AND strftime('%Y-%m-%d', s.tanggal) = strftime('%Y-%m-%d', k.tanggal)
      WHERE strftime('%Y-%m-%d', s.tanggal) = ?
    ''', [dateStr]);

    return List.generate(maps.length, (i) => Stock.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getDailyReport(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T')[0];

    return await db.rawQuery('''
      SELECT 
        p.nama,
        k.modal,
        k.omset,
        k.laba,
        s.stok_awal,
        s.stok_beli,
        s.stok_terjual,
        s.stok_sisa
      FROM keuangan_harian k
      JOIN product p ON k.product_id = p.id
      JOIN stock s ON k.product_id = s.product_id 
        AND strftime('%Y-%m-%d', k.tanggal) = strftime('%Y-%m-%d', s.tanggal)
      WHERE strftime('%Y-%m-%d', k.tanggal) = ?
    ''', [dateStr]);
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('product');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  Future<int> updateStock(Stock stock) async {
    final db = await database;
    return await db.update(
      'stock',
      {
        'stok_awal': stock.stokAwal,
        'stok_beli': stock.stokBeli,
        'stok_terjual': stock.stokTerjual,
        'stok_sisa': stock.stokSisa,
        'tanggal': stock.tanggal.toIso8601String().split('.')[0],
      },
      where: 'id = ?',
      whereArgs: [stock.id],
    );
  }

  Future<int> deleteStock(int id) async {
    final db = await database;
    return await db.delete(
      'stock',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
