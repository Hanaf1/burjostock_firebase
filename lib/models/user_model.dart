// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String role; // PEMILIK atau KARYAWAN
  final int lastLogin;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.lastLogin = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: map['role'] ?? 'KARYAWAN',
      lastLogin: map['lastLogin'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role,
      'lastLogin': lastLogin,
    };
  }
}