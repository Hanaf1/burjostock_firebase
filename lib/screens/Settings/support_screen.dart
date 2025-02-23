import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class SupportCenter extends StatefulWidget {
  const SupportCenter({Key? key}) : super(key: key);

  @override
  State<SupportCenter> createState() => _SupportCenterState();
}

class _SupportCenterState extends State<SupportCenter> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _complaintController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String get userEmail => FirebaseAuth.instance.currentUser?.email ?? 'No Email';

  Future<void> _sendComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    // Hanya mengirim keluhan saja
    final String complaintText = _complaintController.text;

    // Encode email parameters
    final encodedSubject = Uri.encodeComponent('Keluhan Aplikasi BurjoStock');
    final encodedBody = Uri.encodeComponent(complaintText);

    final Uri emailLaunchUri = Uri.parse(
        'mailto:reinkeith79@gmail.com?subject=$encodedSubject&body=$encodedBody'
    );

    try {
      if (await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication)) {
        _resetForm();
        if (mounted) {
          _showSuccessMessage('Email client berhasil dibuka');
        }
      } else {
        if (mounted) {
          _fallbackToClipboard(complaintText);
          _showErrorMessage('Tidak dapat membuka aplikasi email');
        }
      }
    } catch (e) {
      print('Error launching email: $e');
      if (mounted) {
        _fallbackToClipboard(complaintText);
        _showErrorMessage('Gagal membuka email: ${e.toString()}');
      }
    }
  }

  void _fallbackToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        _showErrorMessage('Tidak dapat membuka email. Teks telah disalin ke clipboard');
        _resetForm();
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Gagal menyalin ke clipboard. Silakan coba lagi.');
      }
    }
  }

  void _resetForm() {
    _nameController.clear();
    _phoneController.clear();
    _complaintController.clear();
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _complaintController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pusat Bantuan', style:
          TextStyle(fontFamily: 'Poppins'),),
        centerTitle: true,
        backgroundColor: const Color(0xFF8D6E63),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sampaikan Keluhan Anda',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Mohon isi nama Anda';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),



                TextFormField(
                  controller: _complaintController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Keluhan',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.message),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Mohon isi keluhan Anda';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _sendComplaint,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF8D6E63),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text(
                    'Kirim Keluhan',
                    style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}