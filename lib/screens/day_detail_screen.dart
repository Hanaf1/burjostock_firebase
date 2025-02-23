import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class DayDetailScreen extends StatefulWidget {
  final String dateStr;
  final Map<String, dynamic> dayData;

  const DayDetailScreen({
    Key? key,
    required this.dateStr,
    required this.dayData,
  }) : super(key: key);

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  Map<String, String> productNames = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProductNames();
  }

  Future<void> _loadProductNames() async {
    try {
      final ref = FirebaseDatabase.instance.ref();
      final snapshot = await ref.child('products').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data.forEach((key, value) {
          productNames[key] = (value as Map)['nama'] ?? 'Produk tidak dikenal';
        });
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading product names: $e');
      setState(() {
        isLoading = false;
      });
    }
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

    final dt = DateTime.parse(widget.dateStr);
    final formatter = NumberFormat("#,##0", "id_ID");

    // Filter hanya produk yang terjual
    final Map<String, dynamic> soldProducts = Map.fromEntries(
        widget.dayData.entries.where((entry) {
          final data = entry.value as Map<String, dynamic>;
          final laku = (data['laku'] as num?)?.toInt() ?? 0;
          return laku > 0;
        })
    );

    // Hitung total
    double totalModal = 0;
    double totalLaba = 0;
    double totalOmset = 0;
    int totalLaku = 0;

    soldProducts.forEach((key, value) {
      final data = value as Map<String, dynamic>;
      totalModal += (data['modal'] as num?)?.toDouble() ?? 0;
      totalLaba += (data['laba'] as num?)?.toDouble() ?? 0;
      totalOmset += (data['omset'] as num?)?.toDouble() ?? 0;
      totalLaku += (data['laku'] as num?)?.toInt() ?? 0;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(dt),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.brown,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ringkasan Penjualan",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            "Modal",
                            "Rp ${formatter.format(totalModal.toInt())}",
                            Colors.blue[100]!,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            "Laba",
                            "Rp ${formatter.format(totalLaba.toInt())}",
                            Colors.green[100]!,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            "Omset",
                            "Rp ${formatter.format(totalOmset.toInt())}",
                            Colors.orange[100]!,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            "Terjual",
                            "${formatter.format(totalLaku)} pcs",
                            Colors.purple[100]!,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: soldProducts.isEmpty
                ? Center(
              child: Text(
                'Tidak ada produk yang terjual',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: soldProducts.length,
              itemBuilder: (context, index) {
                final productId = soldProducts.keys.elementAt(index);
                final productData = soldProducts[productId] as Map<String, dynamic>;
                final productName = productNames[productId] ?? 'Produk tidak dikenal';

                final modal = (productData['modal'] as num?)?.toDouble() ?? 0;
                final laba = (productData['laba'] as num?)?.toDouble() ?? 0;
                final omset = (productData['omset'] as num?)?.toDouble() ?? 0;
                final laku = (productData['laku'] as num?)?.toInt() ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow(
                          "Modal",
                          "Rp ${formatter.format(modal.toInt())}",
                          Colors.blue,
                        ),
                        _buildDetailRow(
                          "Laba",
                          "Rp ${formatter.format(laba.toInt())}",
                          Colors.green,
                        ),
                        _buildDetailRow(
                          "Omset",
                          "Rp ${formatter.format(omset.toInt())}",
                          Colors.orange,
                        ),
                        _buildDetailRow(
                          "Terjual",
                          "${formatter.format(laku)} pcs",
                          Colors.purple,
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
    );
  }

  Widget _buildSummaryCard(String label, String value, Color bgColor, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor, // Warna value sesuai parameter
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}