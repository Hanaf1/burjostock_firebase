// lib/screens/edit_stock_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditStockScreen extends StatefulWidget {
  final Map<String, Map<String, String>> stockData;

  const EditStockScreen({Key? key, required this.stockData}) : super(key: key);

  @override
  State<EditStockScreen> createState() => _EditStockScreenState();
}

class _EditStockScreenState extends State<EditStockScreen> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, Map<String, String>> inputData;

  @override
  void initState() {
    super.initState();
    // Copy data untuk editing
    inputData = Map.from(widget.stockData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Log Harian'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // Simulasi penyimpanan data
                print(inputData);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data berhasil disimpan'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: inputData.entries.map((entry) {
            return _buildProductInputCard(entry.key, entry.value);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProductInputCard(String productName, Map<String, String> data) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fastfood, color: Colors.deepOrange, size: 28),
                const SizedBox(width: 12),
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'Stok',
              hint: 'Masukkan stok',
              initialValue: data['stok']!,
              onChanged: (value) {
                inputData[productName]!['stok'] = value;
              },
            ),
            const SizedBox(height: 16),
            _buildInputField(
              label: 'Beli',
              hint: 'Masukkan pembelian',
              initialValue: data['beli']!,
              onChanged: (value) {
                inputData[productName]!['beli'] = value;
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
    required String initialValue,
    required ValueChanged<String> onChanged,
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
        if (value == null || value.isEmpty) {
          return 'Field ini tidak boleh kosong';
        }
        return null;
      },
    );
  }
}
