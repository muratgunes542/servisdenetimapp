import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/auth_service.dart';
import '/utils/constants.dart';

class ProfileEditScreen extends StatefulWidget {
  @override
  _ProfileEditScreenState createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showPasswordSection = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _fullNameController.text = user?['full_name'] ?? '';
        _phoneController.text = user?['phone'] ?? '';
        _departmentController.text = user?['department'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      print('Kullanıcı verisi yükleme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

// _updateProfile metodunda saveUserToLocal çağrısı
  Future<void> _updateProfile() async {
    if (_fullNameController.text.isEmpty) {
      _showSnackBar('Ad soyad alanı zorunludur', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _supabase
          .from(Constants.usersTable)
          .update({
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _departmentController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', _currentUser!['id']);

      // Local storage'ı güncelle - DÜZELTMELİ
      final updatedUser = {
        ..._currentUser!,
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'department': _departmentController.text.trim(),
      };
      await _authService.saveUserToLocal(updatedUser);

      _showSnackBar('Profil başarıyla güncellendi', Colors.green);

    } catch (e) {
      print('Profil güncelleme hatası: $e');
      _showSnackBar('Profil güncellenirken hata oluştu', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Lütfen tüm alanları doldurun', Colors.orange);
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('Yeni şifreler eşleşmiyor', Colors.orange);
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showSnackBar('Şifre en az 6 karakter olmalıdır', Colors.orange);
      return;
    }

    // Mevcut şifreyi kontrol et
    if (_currentPasswordController.text != _currentUser?['password']) {
      _showSnackBar('Mevcut şifre hatalı', Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _supabase
          .from(Constants.usersTable)
          .update({
        'password': _newPasswordController.text,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', _currentUser!['id']);

      _showSnackBar('Şifre başarıyla değiştirildi', Colors.green);

      // Formu temizle
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _showPasswordSection = false);

    } catch (e) {
      print('Şifre değiştirme hatası: $e');
      _showSnackBar('Şifre değiştirilirken hata oluştu', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 3),
      ),
    );
  }

  String _getUserTypeText(String userType) {
    switch (userType) {
      case 'ilce': return 'İlçe MEM';
      case 'denetim': return 'Denetim Görevlisi';
      default: return userType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFFE3F2FD),
        title: Text(
          'Profil Düzenle',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Kullanıcı Bilgisi Kartı
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFFE3F2FD),
                      radius: 40,
                      child: Icon(
                        _currentUser?['user_type'] == 'ilce'
                            ? Icons.admin_panel_settings
                            : Icons.assignment_ind,
                        size: 40,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _currentUser?['full_name'] ?? '',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _currentUser?['email'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getUserTypeText(_currentUser?['user_type'] ?? ''),
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Profil Düzenleme Formu
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profil Bilgileri',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 16),

                    // Ad Soyad
                    TextField(
                      controller: _fullNameController,
                      decoration: InputDecoration(
                        labelText: 'Ad Soyad *',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 12),

                    // Telefon
                    TextField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Telefon',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 12),

                    // Departman
                    TextField(
                      controller: _departmentController,
                      decoration: InputDecoration(
                        labelText: 'Departman',
                        prefixIcon: Icon(Icons.business),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Kaydet Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF2196F3),
                        ),
                        child: _isSaving
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('PROFİLİ GÜNCELLE'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Şifre Değiştirme Bölümü
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Şifre Değiştir',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _showPasswordSection
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Color(0xFF2196F3),
                          ),
                          onPressed: () {
                            setState(() {
                              _showPasswordSection = !_showPasswordSection;
                            });
                          },
                        ),
                      ],
                    ),

                    if (_showPasswordSection) ...[
                      SizedBox(height: 16),

                      // Mevcut Şifre
                      TextField(
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrentPassword,
                        decoration: InputDecoration(
                          labelText: 'Mevcut Şifre *',
                          prefixIcon: Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrentPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureCurrentPassword = !_obscureCurrentPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),

                      // Yeni Şifre
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: 'Yeni Şifre *',
                          prefixIcon: Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 12),

                      // Yeni Şifre Tekrar
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Yeni Şifre Tekrar *',
                          prefixIcon: Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 20),

                      // Şifre Değiştir Butonu
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: _isSaving
                              ? CircularProgressIndicator(color: Colors.white)
                              : Text('ŞİFREYİ DEĞİŞTİR'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}